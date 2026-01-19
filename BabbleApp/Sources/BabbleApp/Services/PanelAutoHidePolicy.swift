struct PanelAutoHidePolicy {
    func shouldAutoHideAfterCompletion(pasteSucceeded: Bool) -> Bool {
        !pasteSucceeded
    }
}
