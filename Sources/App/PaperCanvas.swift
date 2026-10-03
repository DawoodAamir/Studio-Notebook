import PaperKit
import PencilKit
import SwiftUI

#if os(macOS)
  import AppKit
  struct PaperCanvas: NSViewControllerRepresentable {
    @Binding var markup: PaperMarkup
    func makeCoordinator() -> Coordinator { Coordinator(markup: $markup) }
    func makeNSViewController(context: Context) -> CanvasController {
      let controller = CanvasController(markup: markup)
      controller.canvas.delegate = context.coordinator
      return controller
    }
    func updateNSViewController(_ controller: CanvasController, context: Context) {
      context.coordinator.binding = $markup
      if controller.canvas.markup != markup {
        context.coordinator.updating = true
        controller.canvas.markup = markup
        context.coordinator.updating = false
      }
    }
    @MainActor final class Coordinator: NSObject, @MainActor PaperMarkupViewController.Delegate {
      var binding: Binding<PaperMarkup>
      var updating = false
      init(markup: Binding<PaperMarkup>) { binding = markup }
      func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
        if !updating, let markup = controller.markup { binding.wrappedValue = markup }
      }
    }
  }
  @MainActor final class CanvasController: NSViewController {
    let canvas: PaperMarkupViewController
    private let tools = MarkupToolbarViewController(supportedFeatureSet: .latest)
    init(markup: PaperMarkup) {
      canvas = PaperMarkupViewController(markup: markup, supportedFeatureSet: .latest)
      super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(markup:)") }
    private var fittedSize = CGSize.zero
    override func viewDidLayout() {
      super.viewDidLayout()
      let size = canvas.view.bounds.size
      guard size != fittedSize, size.width > 100, size.height > 100,
        let bounds = canvas.markup?.bounds
      else { return }
      canvas.zoomRange = 0.1...4
      canvas.scrollConfiguration.zoomScale = max(
        0.1, min((size.width - 32) / bounds.width, (size.height - 32) / bounds.height))
      canvas.setContentVisibleFrame(bounds, animated: false)
      fittedSize = size
    }
    override func loadView() {
      view = NSView()
      addChild(canvas)
      addChild(tools)
      tools.delegate = canvas
      tools.selectedIndirectPointerTouchMode = .selection
      for child in [tools.view, canvas.view] {
        child.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child)
      }
      NSLayoutConstraint.activate([
        tools.view.heightAnchor.constraint(equalToConstant: 52),
        tools.view.topAnchor.constraint(equalTo: view.topAnchor),
        tools.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        tools.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        canvas.view.topAnchor.constraint(equalTo: tools.view.bottomAnchor),
        canvas.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        canvas.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        canvas.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
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
      if canvas.markup != markup {
        context.coordinator.updating = true
        canvas.markup = markup
        context.coordinator.updating = false
      }
    }
    @MainActor
    final class Coordinator: NSObject, @MainActor PaperMarkupViewController.Delegate,
      PKToolPickerObserver
    {
      var binding: Binding<PaperMarkup>
      var updating = false
      let picker = PKToolPicker()
      weak var canvas: PaperMarkupViewController?
      init(markup: Binding<PaperMarkup>) { binding = markup }
      func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
        if !updating, let markup = controller.markup { binding.wrappedValue = markup }
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
