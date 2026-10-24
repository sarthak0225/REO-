import Foundation
import SwiftUI

public enum TaskStepStatus: String, Sendable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public struct TaskStep: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public var status: TaskStepStatus
    public var detail: String?
    
    public init(id: UUID = UUID(), title: String, status: TaskStepStatus = .pending, detail: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }
}

public struct TaskPlan: Identifiable, Sendable {
    public let id: UUID
    public let userGoal: String
    public var steps: [TaskStep]
    public var isComplete: Bool
    
    public init(id: UUID = UUID(), userGoal: String, steps: [TaskStep], isComplete: Bool = false) {
        self.id = id
        self.userGoal = userGoal
        self.steps = steps
        self.isComplete = isComplete
    }
}

@MainActor
public final class TaskPlanner: ObservableObject {
    public static let shared = TaskPlanner()
    
    @Published public private(set) var activePlan: TaskPlan? = nil
    @Published public private(set) var isPaused: Bool = false
    
    private init() {}
    
    public func createPlan(for goal: String, steps: [String]) -> TaskPlan {
        let taskSteps = steps.map { TaskStep(title: $0) }
        let plan = TaskPlan(userGoal: goal, steps: taskSteps)
        self.activePlan = plan
        self.isPaused = false
        AppLogger.shared.info("Task plan created with \(steps.count) steps for goal: \(goal)", category: .agent)
        return plan
    }
    
    public func setStepStatus(stepIndex: Int, status: TaskStepStatus, detail: String? = nil) {
        guard var plan = activePlan, stepIndex < plan.steps.count else { return }
        plan.steps[stepIndex].status = status
        plan.steps[stepIndex].detail = detail
        
        let allCompleted = plan.steps.allSatisfy { $0.status == .completed }
        if allCompleted {
            plan.isComplete = true
        }
        self.activePlan = plan
    }
    
    public func pausePlan() {
        self.isPaused = true
        AppLogger.shared.info("Task plan execution paused", category: .agent)
    }
    
    public func resumePlan() {
        self.isPaused = false
        AppLogger.shared.info("Task plan execution resumed", category: .agent)
    }
    
    public func cancelPlan() {
        guard var plan = activePlan else { return }
        for i in 0..<plan.steps.count {
            if plan.steps[i].status == .inProgress || plan.steps[i].status == .pending {
                plan.steps[i].status = .cancelled
            }
        }
        plan.isComplete = true
        self.activePlan = plan
        AppLogger.shared.info("Task plan cancelled", category: .agent)
    }
    
    public func clearPlan() {
        self.activePlan = nil
        self.isPaused = false
    }
}
