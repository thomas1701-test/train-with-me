//
//  Train_with_MeTests.swift
//  Train with MeTests
//
//  Created by Thomas on 03.02.26.
//

import Testing
@testable import Train_with_Me

struct Train_with_MeTests {

    @Test func keychainSaveAndLoad() {
        KeychainService.save("test-key-abc123")
        #expect(KeychainService.load() == "test-key-abc123")
        KeychainService.delete()
    }

    @Test func keychainLoadReturnsNilWhenEmpty() {
        KeychainService.delete()
        #expect(KeychainService.load() == nil)
    }

    @Test func keychainDeleteClearsKey() {
        KeychainService.save("will-be-deleted")
        KeychainService.delete()
        #expect(KeychainService.load() == nil)
    }

    @Test func keychainOverwritesPreviousKey() {
        KeychainService.save("first-key")
        KeychainService.save("second-key")
        #expect(KeychainService.load() == "second-key")
        KeychainService.delete()
    }
}
