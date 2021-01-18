import XCTest

@testable import Storage

private typealias MigrationStep = CoreDataIterativeMigrator.MigrationStep
private typealias ModelVersion = ManagedObjectModelsInventory.ModelVersion

/// Test cases for `MigrationStep` functions.
final class CoreDataIterativeMigrator_MigrationStepTests: XCTestCase {

    private var modelsInventory: ManagedObjectModelsInventory!

    override func setUpWithError() throws {
        try super.setUpWithError()
        modelsInventory = try .from(packageName: "WooCommerce", bundle: Bundle(for: CoreDataManager.self))
    }

    override func tearDown() {
        modelsInventory = nil
        super.tearDown()
    }

    func test_steps_returns_MigrationSteps_from_source_to_the_target_model() throws {
        // Given
        let modelVersion23 = ModelVersion(name: "Model 23")
        let modelVersion31 = ModelVersion(name: "Model 31")
        let sourceModel = try XCTUnwrap(modelsInventory.model(for: modelVersion23))
        let targetModel = try XCTUnwrap(modelsInventory.model(for: modelVersion31))

        // When
        let steps = try MigrationStep.steps(using: modelsInventory, source: sourceModel, target: targetModel)

        // Then

        // There should be 8 steps:
        //   - 23 to 24
        //   - 24 to 25
        //   - 25 to 26
        //   - 26 to 27
        //   - 27 to 28
        //   - 28 to 29
        //   - 29 to 30
        //   - 30 to 31
        XCTAssertEqual(steps.count, 8)

        // Assert the values of first and last steps.
        let modelVersion24 = ModelVersion(name: "Model 24")

        let expectedFirstStep = MigrationStep(sourceVersion: modelVersion23,
                                              sourceModel: try XCTUnwrap(modelsInventory.model(for: modelVersion23)),
                                              targetVersion: modelVersion24,
                                              targetModel: try XCTUnwrap(modelsInventory.model(for: modelVersion24)))
        let actualFirstStep = try XCTUnwrap(steps.first)
        XCTAssertEqual(actualFirstStep, expectedFirstStep)

        let modelVersion30 = ModelVersion(name: "Model 30")

        let expectedLastStep = MigrationStep(sourceVersion: modelVersion30,
                                              sourceModel: try XCTUnwrap(modelsInventory.model(for: modelVersion30)),
                                              targetVersion: modelVersion31,
                                              targetModel: try XCTUnwrap(modelsInventory.model(for: modelVersion31)))
        let actualLastStep = try XCTUnwrap(steps.last)
        XCTAssertEqual(actualLastStep, expectedLastStep)
    }

    func test_steps_returns_empty_if_the_source_and_target_are_the_same() {

    }

    func test_steps_returns_empty_if_the_source_is_an_unknown_model() {

    }
}
