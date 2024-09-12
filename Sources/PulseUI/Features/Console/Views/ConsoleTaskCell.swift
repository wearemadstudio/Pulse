// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

@available(iOS 15, visionOS 1, *)
struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store: LoggerStore

    enum EditableArea {
        case header, timestamp, content, footer
    }

    var highlightedArea: EditableArea?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            content.higlighted(highlightedArea == .content)

#if os(iOS) || os(watchOS)
            footer.higlighted(highlightedArea == .footer)
#endif
        }
    }

    // MARK: – Header

#if os(watchOS)
    private var header: some View {
        HStack {
            StatusIndicatorView(state: task.state(in: store))
            info
        }
    }
#else
    private var header: some View {
        HStack(spacing: 6) {
            if task.isMocked {
                MockBadgeView()
            }
            info.higlighted(highlightedArea == .header)

            Spacer()
            ConsoleTimestampView(date: task.createdAt)
                .higlighted(highlightedArea == .timestamp)
                .padding(.trailing, 3)
        }
        .overlay(alignment: .leading) {
            StatusIndicatorView(state: task.state(in: store))
#if os(tvOS)
                .offset(x: -20)
#else
                .offset(x: -15)
#endif
        }
        .overlay(alignment: .trailing) {
            if isDisclosureNeeded {
                ListDisclosureIndicator()
                    .offset(x: 8)
            }
        }
    }

#endif
    private var info: some View {
        let status: Text = Text(ConsoleFormatter.status(for: task, store: store))
            .font(makeFont(size: settings.displayOptions.headerFontSize).weight(.medium))
            .foregroundColor(task.state == .failure ? .red : .primary)

#if os(watchOS)
        return status // Not enough space for anything else
#else

        var text: Text {
            guard settings.displayOptions.isShowingDetails else {
                return status
            }
            let details = settings.displayOptions.headerFields
                .compactMap(makeInfoText)
                .joined(separator: " · ")
            guard !details.isEmpty else {
                return status
            }
            return status + Text(" · \(details)")
                .font(makeFont(size: settings.displayOptions.headerFontSize))
        }
        return text
            .tracking(-0.1)
            .lineLimit(settings.displayOptions.headerLineLimit)
            .foregroundStyle(.secondary)
#endif
    }

    private func makeInfoText(for detail: DisplayOptions.Field) -> String? {
        switch detail {
        case .method:
            task.httpMethod
        case .requestSize:
            byteCount(for: task.requestBodySize)
        case .responseSize:
            byteCount(for: task.responseBodySize)
        case .responseContentType:
            task.responseContentType.map(NetworkLogger.ContentType.init)?.lastComponent.uppercased()
        case .duration:
            ConsoleFormatter.duration(for: task)
        case .host:
            task.host
        case .statusCode:
            task.statusCode != 0 ? task.statusCode.description : nil
        case .taskType:
            NetworkLogger.TaskType(rawValue: task.taskType)?.urlSessionTaskClassName
        case .taskDescription:
            task.taskDescription
        }
    }

    // MARK: – Content

    private var content: some View {
        var method: Text? {
            guard let method = task.httpMethod else {
                return nil
            }
            return Text(method.appending(" "))
                .font(makeFont(size: settings.displayOptions.contentFontSize).weight(.medium).smallCaps())
                .tracking(-0.3)
        }

        var main: Text {
            Text(task.getFormattedContent(options: settings.displayOptions) ?? "–")
                .font(makeFont(size: settings.displayOptions.contentFontSize))
        }

        var text: Text {
            if let method {
                method + main
            } else {
                main
            }
        }

        return text
            .lineLimit(settings.displayOptions.contentLineLimit)
    }

    // MARK: – Footer

    @ViewBuilder
    private var footer: some View {
        if let host = task.host, !host.isEmpty {
            Text(host)
                .lineLimit(settings.displayOptions.footerLineLimit)
                .font(makeFont(size: settings.displayOptions.footerFontSize))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func makeFont(size: Int) -> Font {
        Font.system(size: CGFloat(size) * fontMultiplier)
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

private extension View {
    @ViewBuilder
    func higlighted(_ isHighlighted: Bool) -> some View {
        if isHighlighted {
            self.modifier(Components.makeHighlightModifier())
        } else {
            self
        }
    }
}

#if DEBUG
@available(iOS 15, visionOS 1.0, *)
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
