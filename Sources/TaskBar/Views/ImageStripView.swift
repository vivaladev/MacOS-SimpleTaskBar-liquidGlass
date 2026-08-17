import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageStripView: View {
    var images: [NSImage]
    var onRemove: ((Int) -> Void)?
    var onAdd: (() -> Void)?
    var onOpen: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onTapGesture { onOpen?(index) }

                    if let onRemove {
                        Button {
                            onRemove(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                    }
                }
            }

            if let onAdd, images.count < ImageCodec.maxAttachments {
                Button(action: onAdd) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.glass)
                .help("Прикрепить картинку")
            }
        }
    }
}

@MainActor
enum ImagePicker {
    static func pick(completion: @escaping ([Data]) -> Void) {
        FilePanel.open({ panel in
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.canCreateDirectories = false
            panel.allowedContentTypes = [.image, .png, .jpeg, .heic, .webP, .gif, .bmp, .tiff]
            panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            panel.title = "Картинка к задаче"
            panel.message = "Выберите изображение"
            panel.prompt = "Выбрать"
        }) { panel, ok in
            guard ok else {
                completion([])
                return
            }
            completion(panel.urls.compactMap { ImageCodec.jpegData(from: $0) })
        }
    }

    static func nsImages(from data: [Data]) -> [NSImage] {
        data.compactMap { NSImage(data: $0) }
    }
}
