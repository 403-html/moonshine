//
//  WhiskyWineDownloadView.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import WhiskyKit

struct WhiskyWineDownloadView: View {
    @State private var fractionProgress: Double = 0
    @State private var completedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var downloadSpeed: Double = 0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var observation: NSKeyValueObservation?
    @State private var startTime: Date?
    @Binding var tarLocation: URL
    @Binding var path: [SetupStage]
    var body: some View {
        VStack {
            VStack {
                Text("setup.whiskywine.download")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.whiskywine.download.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack {
                    ProgressView(value: fractionProgress, total: 1)
                    HStack {
                        HStack {
                            Text(String(format: String(localized: "setup.whiskywine.progress"),
                                        formatBytes(bytes: completedBytes),
                                        formatBytes(bytes: totalBytes)))
                            + Text(String(" "))
                            + (shouldShowEstimate() ?
                               Text(String(format: String(localized: "setup.whiskywine.eta"),
                                           formatRemainingTime(remainingBytes: totalBytes - completedBytes)))
                               : Text(String()))
                            Spacer()
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            Spacer()
        }
        .frame(width: 400, height: 200)
        .onAppear {
            startDownload()
        }
    }

    @MainActor
    func startDownload() {
        observation?.invalidate()
        fractionProgress = 0
        completedBytes = 0
        totalBytes = 0
        let wineURL = "https://github.com/Gcenx/macOS_Wine_builds/"
            + "releases/download/11.10/wine-staging-11.10-osx64.tar.xz"
        guard let url = URL(string: wineURL) else { return }

        downloadTask = URLSession(configuration: .ephemeral)
            .downloadTask(with: url) { localURL, response, error in
                Task.detached {
                    await MainActor.run {
                        if let error = error {
                            showDownloadError(error.localizedDescription)
                            return
                        }
                        if let httpResponse = response as? HTTPURLResponse,
                           !(200...299).contains(httpResponse.statusCode) {
                            showDownloadError(String(
                                format: String(localized: "setup.whiskywine.download.httpError"),
                                httpResponse.statusCode
                            ))
                            return
                        }
                        guard let localURL = localURL else {
                            showDownloadError(String(localized: "setup.whiskywine.download.noFile"))
                            return
                        }
                        tarLocation = localURL
                        proceed()
                    }
                }
            }
        observation = downloadTask?.observe(\.countOfBytesReceived) { task, _ in
            Task {
                await MainActor.run {
                    let currentTime = Date()
                    let elapsedTime = currentTime.timeIntervalSince(startTime ?? currentTime)
                    if completedBytes > 0 {
                        downloadSpeed = Double(completedBytes) / elapsedTime
                    }
                    totalBytes = task.countOfBytesExpectedToReceive
                    completedBytes = task.countOfBytesReceived
                    fractionProgress = Double(completedBytes) / Double(totalBytes)
                }
            }
        }
        startTime = Date()
        downloadTask?.resume()
    }

    func formatBytes(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }

    func shouldShowEstimate() -> Bool {
        let elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        return Int(elapsedTime.rounded()) > 5 && completedBytes != 0
    }

    func formatRemainingTime(remainingBytes: Int64) -> String {
        let remainingTimeInSeconds = Double(remainingBytes) / downloadSpeed

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        if shouldShowEstimate() {
            return formatter.string(from: TimeInterval(remainingTimeInSeconds)) ?? ""
        } else {
            return ""
        }
    }

    func proceed() {
        path.append(.whiskyWineInstall)
    }

    @MainActor
    func showDownloadError(_ message: String) {
        observation?.invalidate()
        let alert = NSAlert()
        alert.messageText = String(localized: "setup.whiskywine.download.failed")
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "setup.whiskywine.download.retry"))
        alert.addButton(withTitle: String(localized: "button.cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            startDownload()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
}
