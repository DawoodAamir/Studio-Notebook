import PaperKit
import PencilKit
import SwiftUI

#if os(macOS)
  import AppKit

  struct PaperCanvas: View {
    @Binding var markup: PaperMarkup
    @State private var controllers: MacCanvasControllers?

    var body: some View {
      Group {
        if let controllers {
          VStack(spacing: 0) {
            MacMarkupTools(controllers: controllers)
              .frame(height: 52)
            MacMarkupSurface(markup: $markup, controllers: controllers)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .onGeometryChange(for: CGSize.self) {
                $0.size
              } action: { size in
                controllers.scheduleFit(size: size)
              }
          }
        } else {
          ProgressView("Opening canvas")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .task {
        if controllers == nil { controllers = MacCanvasControllers(markup: markup) }
      }
      .onDisappear { controllers?.fitTask?.cancel() }
    }
  }

  @MainActor private final class MacCanvasControllers {
    let canvas: PaperMarkupViewController
    let tools = MarkupToolbarViewController(supportedFeatureSet: .latest)
    var fitTask: Task<Void, Never>?
    var needsFit = false

    init(markup: PaperMarkup) {
      canvas = PaperMarkupViewController(markup: markup, supportedFeatureSet: .latest)
      let page = NSView(frame: markup.bounds)
      page.wantsLayer = true
      page.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
      canvas.contentView = page
      tools.delegate = canvas
      tools.selectedIndirectPointerTouchMode = .selection
      canvas.zoomRange = 0.1...4
    }

    func scheduleFit(size: CGSize) {
      needsFit = true
      fitTask?.cancel()
      fitTask = Task { [weak self] in
        await Task.yield()
        guard !Task.isCancelled, let self, size.width > 100, size.height > 100,
          let bounds = canvas.markup?.bounds
        else { return }
        guard !canvas.contentVisibleFrame.isEmpty else { return }
        needsFit = false
        canvas.scrollConfiguration.zoomScale = max(
          0.1, min((size.width - 32) / bounds.width, (size.height - 32) / bounds.height))
        canvas.contentVisibleFrame = bounds.insetBy(dx: -24, dy: -24)
      }
    }
  }

  private struct MacMarkupTools: NSViewControllerRepresentable {
    let controllers: MacCanvasControllers
    func makeNSViewController(context: Context) -> MarkupToolbarViewController { controllers.tools }
    func updateNSViewController(_ controller: MarkupToolbarViewController, context: Context) {}
    func sizeThatFits(
      _ proposal: ProposedViewSize, nsViewController: MarkupToolbarViewController,
      context: Context
    ) -> CGSize? {
      CGSize(width: proposal.width ?? 640, height: 52)
    }
  }

  private struct MacMarkupSurface: NSViewControllerRepresentable {
    @Binding var markup: PaperMarkup
    let controllers: MacCanvasControllers
    func makeCoordinator() -> Coordinator { Coordinator(markup: $markup, controllers: controllers) }
    func makeNSViewController(context: Context) -> PaperMarkupViewController {
      controllers.canvas.delegate = context.coordinator
      context.coordinator.lastNative = controllers.canvas.markup
      return controllers.canvas
    }
    func updateNSViewController(_ controller: PaperMarkupViewController, context: Context) {
      context.coordinator.binding = $markup
      // PaperKit merges revision metadata; compare the last model input to avoid feedback.
      if context.coordinator.lastInput != markup {
        context.coordinator.lastInput = markup
        context.coordinator.updating = true
        controller.markup = markup
        context.coordinator.lastNative = controller.markup
        context.coordinator.updating = false
      }
    }
    func sizeThatFits(
      _ proposal: ProposedViewSize, nsViewController: PaperMarkupViewController,
      context: Context
    ) -> CGSize? {
      CGSize(width: proposal.width ?? 640, height: proposal.height ?? 700)
    }
    @MainActor final class Coordinator: NSObject, @MainActor PaperMarkupViewController.Delegate {
      var binding: Binding<PaperMarkup>
      var updating = false
      var lastInput: PaperMarkup
      var lastNative: PaperMarkup?
      let controllers: MacCanvasControllers
      init(markup: Binding<PaperMarkup>, controllers: MacCanvasControllers) {
        binding = markup
        lastInput = markup.wrappedValue
        self.controllers = controllers
      }
      func paperMarkupViewControllerDidChangeContentVisibleFrame(
        _ controller: PaperMarkupViewController
      ) {
        if controllers.needsFit, !controller.contentVisibleFrame.isEmpty {
          controllers.scheduleFit(size: controller.view.bounds.size)
        }
      }
      func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
        guard !updating, let markup = controller.markup, markup != lastNative else { return }
        lastNative = markup
        lastInput = markup
        binding.wrappedValue = markup
      }
    }
  }
#else
  import UIKit
  struct PaperCanvas: UIViewControllerRepresentable {
    @Binding var markup: PaperMarkup
    func makeCoordinator() -> Coordinator { Coordinator(markup: $markup) }
    func makeUIViewController(context: Context) -> PaperMarkupViewController {
      let canvas = PaperMarkupViewController(markup: markup, supportedFeatureSet: .latest)
      canvas.delegate = context.coordinator
      context.coordinator.lastNative = canvas.markup
      canvas.directTouchMode = .drawing
      canvas.indirectPointerTouchMode = .selection
      context.coordinator.canvas = canvas
      context.coordinator.picker.addObserver(context.coordinator)
      canvas.loadViewIfNeeded()
      context.coordinator.picker.setVisible(true, forFirstResponder: canvas)
      canvas.becomeFirstResponder()
      return canvas
    }
    func updateUIViewController(_ canvas: PaperMarkupViewController, context: Context) {
      context.coordinator.binding = $markup
      // PaperKit merges revision metadata; compare the last model input to avoid feedback.
      if context.coordinator.lastInput != markup {
        context.coordinator.lastInput = markup
        context.coordinator.updating = true
        canvas.markup = markup
        context.coordinator.lastNative = canvas.markup
        context.coordinator.updating = false
      }
    }
    @MainActor
    final class Coordinator: NSObject, @MainActor PaperMarkupViewController.Delegate,
      PKToolPickerObserver
    {
      var binding: Binding<PaperMarkup>
      var updating = false
      var lastInput: PaperMarkup
      var lastNative: PaperMarkup?
      let picker = PKToolPicker()
      weak var canvas: PaperMarkupViewController?
      init(markup: Binding<PaperMarkup>) {
        binding = markup
        lastInput = markup.wrappedValue
      }
      func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
        guard !updating, let markup = controller.markup, markup != lastNative else { return }
        lastNative = markup
        lastInput = markup
        binding.wrappedValue = markup
      }
      func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
        canvas?.toolPickerSelectedToolItemDidChange(toolPicker)
      }
      func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) {
        canvas?.toolPickerIsRulerActiveDidChange(toolPicker)
      }
    }
  }
#endif
