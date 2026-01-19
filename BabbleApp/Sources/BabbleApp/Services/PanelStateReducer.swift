struct PanelStateReducer {
    func finalPanelStateAfterDelay(
        pasteSucceeded: Bool,
        current: FloatingPanelState
    ) -> FloatingPanelState {
        if pasteSucceeded {
            return FloatingPanelState(status: .idle, message: nil)
        }
        return current
    }
}
