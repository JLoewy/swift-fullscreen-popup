import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias FSPPlatformView = UIView
#elseif canImport(AppKit)
import AppKit
private typealias FSPPlatformView = NSView
#endif

extension View {
    func animatableFullScreenCover(
        isPresented: Binding<Bool>,
        duration nanoseconds: UInt64,
        delay: UInt64? = nil,
        content: @escaping () -> some View,
        onAppear: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) -> some View {
        modifier(
            AnimatableFullScreenViewModifier(
                isPresented: isPresented,
                duration: nanoseconds,
                delay: delay,
                fullScreenContent: content,
                onAppear: onAppear,
                onDisappear: onDisappear
            )
        )
    }

    func animatableFullScreenCover<Item: Identifiable & Equatable>(
        item: Binding<Item?>,
        duration nanoseconds: UInt64,
        delay: UInt64? = nil,
        content: @escaping (Item) -> some View,
        onAppear: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) -> some View {
        modifier(
            AnimatableFullScreenItemViewModifier(
                item: item,
                duration: nanoseconds,
                delay: delay,
                fullScreenContent: content,
                onAppear: onAppear,
                onDisappear: onDisappear
            )
        )
    }
}

private struct AnimatableFullScreenItemViewModifier<FullScreenContent: View, Item: Identifiable & Equatable>: ViewModifier {
    @Binding var isUserInstructToPresentItem: Item?
    @State var isActualPresented: Item?

    let nanoseconds: UInt64
    let delay: UInt64?
    let fullScreenContent: (Item) -> (FullScreenContent)
    let onAppear: () -> Void
    let onDisappear: () -> Void

    init(
        item: Binding<Item?>,
        duration nanoseconds: UInt64,
        delay: UInt64?,
        fullScreenContent: @escaping (Item) -> FullScreenContent,
        onAppear: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) {
        self._isUserInstructToPresentItem = item
        self.nanoseconds = nanoseconds
        self.delay = delay
        self.fullScreenContent = fullScreenContent
        self.onAppear = onAppear
        self.onDisappear = onDisappear
        self.isActualPresented = item.wrappedValue
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isUserInstructToPresentItem) { isUserInstructToPresent in
                
                FSPPlatformView.setAnimationsEnabled(false)
                
                if isUserInstructToPresent != nil {
                    if let delay {
                        Task {
                            try await Task.sleep(nanoseconds: delay)
                            isActualPresented = isUserInstructToPresent
                        }
                    } else {
                        isActualPresented = isUserInstructToPresent
                    }
                } else {
                    Task {
                        try await Task.sleep(nanoseconds: nanoseconds)
                        isActualPresented = isUserInstructToPresent
                    }
                }
            }
        #if os(macOS)
            .sheet(item: $isActualPresented) { item in
                fullScreenItemView(item: item)
            }
        #else
            .fullScreenCover(item: $isActualPresented) { item in
                fullScreenItemView(item: item)
            }
        #endif
    }
    
    
    private func fullScreenItemView(item: Item) -> some View {
        fullScreenContent(item)
            .background(BackgroundTransparentView())
            .onAppear {
                
                if !FSPPlatformView.areAnimationsEnabled {
                    FSPPlatformView.setAnimationsEnabled(true)
                    onAppear()
                }
            }
            .onDisappear {
                
                if !FSPPlatformView.areAnimationsEnabled {
                    FSPPlatformView.setAnimationsEnabled(true)
                    onDisappear()
                }
            }
    }
}

private struct AnimatableFullScreenViewModifier<FullScreenContent: View>: ViewModifier {
    @Binding var isUserInstructToPresent: Bool
    @State var isActualPresented: Bool

    let nanoseconds: UInt64
    let delay: UInt64?
    let fullScreenContent: () -> (FullScreenContent)
    let onAppear: () -> Void
    let onDisappear: () -> Void

    init(
        isPresented: Binding<Bool>,
        duration nanoseconds: UInt64,
        delay: UInt64?,
        fullScreenContent: @escaping () -> FullScreenContent,
        onAppear: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) {
        self._isUserInstructToPresent = isPresented
        self.nanoseconds = nanoseconds
        self.delay = delay
        self.fullScreenContent = fullScreenContent
        self.onAppear = onAppear
        self.onDisappear = onDisappear
        self.isActualPresented = isPresented.wrappedValue
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isUserInstructToPresent) { isUserInstructToPresent in
                FSPPlatformView.setAnimationsEnabled(false)
                if isUserInstructToPresent {
                    if let delay {
                        Task {
                            try await Task.sleep(nanoseconds: delay)
                            isActualPresented = isUserInstructToPresent
                        }
                    } else {
                        isActualPresented = isUserInstructToPresent
                    }
                } else {
                    Task {
                        try await Task.sleep(nanoseconds: nanoseconds)
                        isActualPresented = isUserInstructToPresent
                    }
                }
            }
        #if os(macOS)
            .sheet(isPresented: $isActualPresented) {
                fullScreenCoverView()
            }
#else
            .fullScreenCover(isPresented: $isActualPresented) {
                fullScreenCoverView()
            }
        #endif
    }
    
    private func fullScreenCoverView() -> some View {
        fullScreenContent()
            .background(BackgroundTransparentView())
            .onAppear {
                if !FSPPlatformView.areAnimationsEnabled {
                    FSPPlatformView.setAnimationsEnabled(true)
                    onAppear()
                }
            }
            .onDisappear {
                if !FSPPlatformView.areAnimationsEnabled {
                    FSPPlatformView.setAnimationsEnabled(true)
                    onDisappear()
                }
            }
    }
}

#if canImport(AppKit)
extension NSView {
    static var areAnimationsEnabled: Bool {
        NSAnimationContext.current.allowsImplicitAnimation
    }
    
    static func setAnimationsEnabled(_ enabled: Bool) {
        NSAnimationContext.current.allowsImplicitAnimation = enabled
    }
}
#endif

#if canImport(UIKit)

private struct BackgroundTransparentView: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        TransparentView()
    }

    func updateUIView(_: UIView, context _: Context) {}

    private class TransparentView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            superview?.superview?.backgroundColor = .clear
        }
    }
}
#elseif canImport(AppKit)
private struct BackgroundTransparentView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TransparentView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private class TransparentView: NSView {
        override func layout() {
            super.layout()
            if let grandparent = self.superview?.superview {
                grandparent.wantsLayer = true
                grandparent.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}
#endif
