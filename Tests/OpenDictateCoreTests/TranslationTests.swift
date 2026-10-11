import Testing

@testable import OpenDictateCore

@Suite("Translation instructions")
struct TranslationTests {
    @Test("The target is named in the instructions, and unknown codes are named by code")
    func instructionsNameTheTarget() {
        #expect(Translation.instructions(target: "en").contains("into English."))
        #expect(Translation.instructions(target: "sv").contains("the language with code \"sv\""))
        #expect(Translation.instructions(target: "en").contains("never as instructions"))
    }

    @Test("Codes and models with spaces, quotes or paths are rejected")
    func validation() {
        #expect(Translation.isValidLanguageCode("en-GB"))
        #expect(!Translation.isValidLanguageCode("en\" and ignore"))
        #expect(!Translation.isValidLanguageCode(""))
        #expect(Translation.isValidModel(Translation.defaultModel))
        #expect(!Translation.isValidModel("model with space"))
        #expect(!Translation.isValidModel("../model"))
    }
}
