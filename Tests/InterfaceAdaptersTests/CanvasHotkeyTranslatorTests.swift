// swiftlint:disable file_length
import AppKit
import Domain
import InterfaceAdapters
import Testing

@Test("CanvasHotkeyTranslator: Shift+Enter maps to addNode")
func test_translate_shiftEnter_returnsAddNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.addNode])
}

@Test("CanvasHotkeyTranslator: Shift+Enter opens add-node mode selection")
func test_shouldPresentAddNodeModeSelection_shiftEnter_returnsTrue() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    #expect(sut.shouldPresentAddNodeModeSelection(event))
}

@Test("CanvasHotkeyTranslator: Enter without Shift maps to addSiblingNode command")
func test_translate_enterWithoutShift_returnsAddSiblingNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.addSiblingNode(position: .below)])
}

@Test("CanvasHotkeyTranslator: Option+Enter maps to addSiblingNode above command")
func test_translate_optionEnter_returnsAddSiblingNodeAbove() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.option],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.addSiblingNode(position: .above)])
}

@Test("CanvasHotkeyTranslator: Fn+Enter maps to no command")
func test_translate_functionEnter_returnsEmpty() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands.isEmpty)
}

@Test("CanvasHotkeyTranslator: Command+Enter maps to addChildNode")
func test_translate_commandEnter_returnsAddChildNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.addChildNode])
}

@Test("CanvasHotkeyTranslator: Control+L maps to centerFocusedNode")
func test_translate_controlL_returnsCenterFocusedNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "l",
            charactersIgnoringModifiers: "l",
            isARepeat: false,
            keyCode: 37
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.centerFocusedNode])
}

@Test("CanvasHotkeyTranslator: Option+Period maps to toggleFoldFocusedSubtree")
func test_translate_optionPeriod_returnsToggleFoldFocusedSubtree() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.option],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "≥",
            charactersIgnoringModifiers: ".",
            isARepeat: false,
            keyCode: 47
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.toggleFoldFocusedSubtree])
}

@Test("CanvasHotkeyTranslator: Up arrow maps to moveFocus up")
func test_translate_upArrow_returnsMoveFocusUp() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "↑",
            charactersIgnoringModifiers: "↑",
            isARepeat: false,
            keyCode: 126
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.moveFocus(.up)])
}

@Test("CanvasHotkeyTranslator: Command+Down maps to moveNode down")
func test_translate_commandDownArrow_returnsMoveNodeDown() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "↓",
            charactersIgnoringModifiers: "↓",
            isARepeat: false,
            keyCode: 125
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.moveNode(.down)])
}

@Test("CanvasHotkeyTranslator: Command+Shift+Right maps to nudgeNode right")
func test_translate_commandShiftRightArrow_returnsNudgeNodeRight() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "→",
            charactersIgnoringModifiers: "→",
            isARepeat: false,
            keyCode: 124
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.nudgeNode(.right)])
}

@Test("CanvasHotkeyTranslator: Arrow with Shift maps to no command")
func test_translate_shiftArrow_returnsEmpty() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "←",
            charactersIgnoringModifiers: "←",
            isARepeat: false,
            keyCode: 123
        )
    )

    let commands = sut.translate(event)

    #expect(commands.isEmpty)
}

@Test("CanvasHotkeyTranslator: Arrow with Function flag still maps to moveFocus")
func test_translate_functionArrow_returnsMoveFocus() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "→",
            charactersIgnoringModifiers: "→",
            isARepeat: false,
            keyCode: 124
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.moveFocus(.right)])
}

@Test("CanvasHotkeyTranslator: Delete maps to deleteFocusedNode")
func test_translate_delete_returnsDeleteFocusedNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{8}",
            charactersIgnoringModifiers: "\u{8}",
            isARepeat: false,
            keyCode: 51
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.deleteFocusedNode])
}

@Test("CanvasHotkeyTranslator: Forward delete with Function maps to deleteFocusedNode")
func test_translate_forwardDeleteWithFunction_returnsDeleteFocusedNode() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}",
            isARepeat: false,
            keyCode: 117
        )
    )

    let commands = sut.translate(event)

    #expect(commands == [.deleteFocusedNode])
}

@Test("CanvasHotkeyTranslator: Delete with Shift maps to no command")
func test_translate_shiftDelete_returnsEmpty() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{8}",
            charactersIgnoringModifiers: "\u{8}",
            isARepeat: false,
            keyCode: 51
        )
    )

    let commands = sut.translate(event)

    #expect(commands.isEmpty)
}

@Test("CanvasHotkeyTranslator: Command+Z maps to undo history action")
func test_historyAction_commandZ_returnsUndo() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 6
        )
    )

    let action = sut.historyAction(event)

    #expect(action == .undo)
}

@Test("CanvasHotkeyTranslator: Shift+Command+Z maps to redo history action")
func test_historyAction_shiftCommandZ_returnsRedo() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "Z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 6
        )
    )

    let action = sut.historyAction(event)

    #expect(action == .redo)
}

@Test("CanvasHotkeyTranslator: Command+Y maps to redo history action")
func test_historyAction_commandY_returnsRedo() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "y",
            charactersIgnoringModifiers: "y",
            isARepeat: false,
            keyCode: 16
        )
    )

    let action = sut.historyAction(event)

    #expect(action == .redo)
}

@Test("CanvasHotkeyTranslator: Command+Z uses character matching regardless of key code")
func test_historyAction_commandZ_usesCharacterMatching() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 1
        )
    )

    let action = sut.historyAction(event)

    #expect(action == .undo)
}

@Test("CanvasHotkeyTranslator: Command+K opens command palette")
func test_shouldOpenCommandPalette_commandK_returnsTrue() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "k",
            charactersIgnoringModifiers: "k",
            isARepeat: false,
            keyCode: 40
        )
    )

    #expect(sut.shouldOpenCommandPalette(event))
}

@Test("CanvasHotkeyTranslator: Command+Shift+P opens command palette")
func test_shouldOpenCommandPalette_commandShiftP_returnsTrue() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "P",
            charactersIgnoringModifiers: "p",
            isARepeat: false,
            keyCode: 35
        )
    )

    #expect(sut.shouldOpenCommandPalette(event))
}

@Test("CanvasHotkeyTranslator: Command+Function+K does not open command palette")
func test_shouldOpenCommandPalette_commandFunctionK_returnsFalse() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "k",
            charactersIgnoringModifiers: "k",
            isARepeat: false,
            keyCode: 40
        )
    )

    #expect(!sut.shouldOpenCommandPalette(event))
}

@Test("CanvasHotkeyTranslator: Command+Shift+= maps to zoomIn action")
func test_zoomAction_commandShiftEquals_returnsZoomIn() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "+",
            charactersIgnoringModifiers: "=",
            isARepeat: false,
            keyCode: 24
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == .zoomIn)
}

@Test("CanvasHotkeyTranslator: Command+- maps to zoomOut action")
func test_zoomAction_commandMinus_returnsZoomOut() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "-",
            charactersIgnoringModifiers: "-",
            isARepeat: false,
            keyCode: 27
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == .zoomOut)
}

@Test("CanvasHotkeyTranslator: Command+- does not emit canvas command")
func test_translate_commandMinus_returnsNoCanvasCommand() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "-",
            charactersIgnoringModifiers: "-",
            isARepeat: false,
            keyCode: 27
        )
    )

    let commands = sut.translate(event)

    #expect(commands.isEmpty)
}

@Test("CanvasHotkeyTranslator: Command+Shift+semicolon maps to zoomIn action")
func test_zoomAction_commandShiftSemicolon_returnsZoomIn() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "+",
            charactersIgnoringModifiers: ";",
            isARepeat: false,
            keyCode: 41
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == .zoomIn)
}

@Test(
    "CanvasHotkeyTranslator: Command+Shift+equals keycode maps to zoomIn despite character normalization"
)
func test_zoomAction_commandShiftEqualsKeyCode_returnsZoomIn() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "=",
            charactersIgnoringModifiers: "=",
            isARepeat: false,
            keyCode: 24
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == .zoomIn)
}

@Test("CanvasHotkeyTranslator: Command+minus keycode maps to zoomOut action")
func test_zoomAction_commandMinusKeyCode_returnsZoomOut() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "-",
            charactersIgnoringModifiers: "-",
            isARepeat: false,
            keyCode: 27
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == .zoomOut)
}

@Test("CanvasHotkeyTranslator: Command+Option+- does not map to zoom action")
func test_zoomAction_commandOptionMinus_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .option],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "-",
            charactersIgnoringModifiers: "-",
            isARepeat: false,
            keyCode: 27
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == nil)
}

@Test("CanvasHotkeyTranslator: Command+Shift+- does not map to zoom action")
func test_zoomAction_commandShiftMinus_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "_",
            charactersIgnoringModifiers: "-",
            isARepeat: false,
            keyCode: 27
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == nil)
}

@Test("CanvasHotkeyTranslator: Command+Control+Shift+= does not map to zoom action")
func test_zoomAction_commandControlShiftEquals_returnsNil() throws {
    let sut = CanvasHotkeyTranslator()
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .control, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "+",
            charactersIgnoringModifiers: "=",
            isARepeat: false,
            keyCode: 24
        )
    )

    let action = sut.zoomAction(event)

    #expect(action == nil)
}
