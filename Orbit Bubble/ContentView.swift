import SwiftUI
import Combine
import WebKit
import AppsFlyerLib
import Firebase
import FirebaseMessaging

struct TaskEntity: Identifiable, Codable {
    let id = UUID()
    var title: String
    var description: String
    var priority: Priority
    var deadline: Date?
    var isCompleted: Bool
    var subtasks: [Subtask]
    
    enum Priority: String, CaseIterable, Codable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var radius: CGFloat {
            switch self {
            case .high: return 80
            case .medium: return 140
            case .low: return 200
            }
        }
        
        var colorOpacity: Double {
            switch self {
            case .high: return 1.0
            case .medium: return 0.8
            case .low: return 0.6
            }
        }
    }
}

struct Subtask: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
}

struct Goal: Identifiable, Codable {
    let id = UUID()
    var title: String
    var tasks: [TaskEntity]
    var progress: Double
}


class TaskManager: ObservableObject {
    @Published var tasks: [TaskEntity] = []
    @Published var goals: [Goal] = []
    @Published var selectedTask: TaskEntity?
    
    private let tasksKey = "savedTasks"
    private let goalsKey = "savedGoals"
    
    init() {
        loadData()
    }
    
    func addTask(_ task: TaskEntity) {
        tasks.append(task)
        saveData()
    }
    
    func updateTask(_ task: TaskEntity) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveData()
        }
    }
    
    func deleteTask(_ taskId: UUID) {
        tasks.removeAll { $0.id == taskId }
        saveData()
    }
    
    func completeTask(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].isCompleted.toggle()
            saveData()
        }
    }
    
    func saveData() {
        if let encodedTasks = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encodedTasks, forKey: tasksKey)
        }
        if let encodedGoals = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encodedGoals, forKey: goalsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decodedTasks = try? JSONDecoder().decode([TaskEntity].self, from: data) {
            tasks = decodedTasks
        }
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decodedGoals = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decodedGoals
        }
    }
}

struct ContentView: View {
    @StateObject private var taskManager = TaskManager()
    @State private var selectedTab = 0
    @State private var showAddTask = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OrbitView(taskManager: taskManager)
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Orbit")
                }
                .tag(0)
            
            GoalsView(taskManager: taskManager)
                .tabItem {
                    Image(systemName: "network")
                    Text("Goals")
                }
                .tag(1)
            
            StatsView(taskManager: taskManager)
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.pink)
        .background(
            CosmicBackground()
        )
        .sheet(isPresented: $showAddTask) {
            AddTaskView(taskManager: taskManager)
        }
        .preferredColorScheme(.dark)
    }
}

struct OrbitView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var rotationAngle: Angle = .degrees(0)
    @State private var showTaskDetails = false
    @State private var showAddTask = false
    
    var body: some View {
        ZStack {
            CosmicBackground()
            
            // Центральное ядро
            CoreView()
                .scaleEffect(0.8)
            
            // Орбиты с задачами
            ForEach(taskManager.tasks) { task in
                OrbitTaskView(task: task, rotationAngle: rotationAngle)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            taskManager.selectedTask = task
                            showTaskDetails = true
                        }
                    }
            }
            
            VStack {
                Spacer()
                AddTaskButton {
                    withAnimation(.easeInOut) {
                        showAddTask = true
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = .degrees(360)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(taskManager: taskManager)
        }
        .fullScreenCover(item: $taskManager.selectedTask) { task in
            TaskDetailsView(task: task, taskManager: taskManager)
        }
    }
}

struct OrbitTaskView: View {
    let task: TaskEntity
    let rotationAngle: Angle
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Орбита
            OrbitPath(radius: task.priority.radius)
                .stroke(
                    Color(hex: "7A4FFF").opacity(0.3),
                    lineWidth: 1
                )
            
            // Планета задачи
            PlanetView(
                title: task.title,
                isCompleted: task.isCompleted,
                pulse: pulse
            )
            .offset(y: -task.priority.radius)
            .rotationEffect(rotationAngle)
            .rotationEffect(.degrees(Double(task.id.uuidString.hashValue % 360)))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct CosmicBackground: View {
    @State private var start = UnitPoint(x: 0, y: 0)
    @State private var end = UnitPoint(x: 1, y: 1)
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "0D0D1A"),
                        Color(hex: "1A0D2E"),
                        Color(hex: "2B0D4F")
                    ],
                    startPoint: start,
                    endPoint: end
                )
                .ignoresSafeArea()
                
                // Добавляем звёзды для эффекта
                ForEach(0..<20) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 2...5), height: CGFloat.random(in: 2...5))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    start = UnitPoint(x: 1, y: 0)
                    end = UnitPoint(x: 0, y: 1)
                    offsetX = CGFloat.random(in: -20...20)
                    offsetY = CGFloat.random(in: -20...20)
                }
            }
        }
    }
}

struct CoreView: View {
    @State private var glowScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FF4FBF").opacity(0.8),
                            Color(hex: "B84FFF").opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(glowScale)
            
            Circle()
                .fill(Color(hex: "FF4FBF"))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowScale = 1.1
            }
        }
    }
}

struct PlanetView: View {
    let title: String
    let isCompleted: Bool
    let pulse: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isCompleted ? Color(hex: "FFD84F") : Color(hex: "FF4FBF"),
                                isCompleted ? Color(hex: "FFD84F").opacity(0.4) : Color(hex: "B84FFF").opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                
                Circle()
                    .fill(isCompleted ? Color(hex: "FFD84F") : Color(hex: "FF4FBF"))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                isCompleted ? Color(hex: "FFD84F").opacity(0.6) : Color(hex: "B84FFF").opacity(0.6),
                                lineWidth: 3
                            )
                    )
                    .shadow(
                        color: isCompleted ? Color(hex: "FFD84F") : Color(hex: "B84FFF"),
                        radius: pulse ? 15 : 8,
                        x: 0, y: 0
                    )
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
    }
}

struct OrbitPath: Shape {
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addEllipse(
                in: CGRect(
                    x: rect.midX - radius,
                    y: rect.midY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
        }
    }
}

struct TaskDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskEntity
    @ObservedObject var taskManager: TaskManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Главная планета с подзадачами
                    TaskOrbitView(task: task)
                    
                    // Информация о задаче
                    TaskInfoView(task: task)
                    
                    // Кнопки действий
                    ActionButtonsView(task: task, taskManager: taskManager)
                }
                .padding()
            }
            .navigationTitle(task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .background(CosmicBackground())
    }
}

struct TaskOrbitView: View {
    let task: TaskEntity
    
    var body: some View {
        ZStack {
            PlanetView(title: task.title, isCompleted: task.isCompleted, pulse: true)
                .scaleEffect(1.5)
            
            ForEach(task.subtasks) { subtask in
                Circle()
                    .fill(Color.pink.opacity(0.6))
                    .frame(width: 20, height: 20)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(subtask.id.uuidString.hashValue % 360)))
            }
        }
        .frame(height: 200)
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var taskManager: TaskManager
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskEntity.Priority = .medium
    @State private var deadline: Date = Date()
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            CosmicBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("New Task")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "B84FFF").opacity(0.5), radius: 5)
                
                // Поле для названия
                TextField("Task Title", text: $title)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color(hex: "FF4FBF").opacity(0.3), lineWidth: 2)
                            )
                    )
                    .shadow(color: Color(hex: "B84FFF").opacity(isAnimating ? 0.5 : 0.3), radius: 10)
                
                // Поле для описания
                TextField("Description", text: $description)
                    .font(.body)
                    .foregroundColor(Color(hex: "CCCCCC"))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color(hex: "FF4FBF").opacity(0.3), lineWidth: 2)
                            )
                    )
                    .shadow(color: Color(hex: "B84FFF").opacity(isAnimating ? 0.5 : 0.3), radius: 10)
                
                // Приоритет
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskEntity.Priority.allCases, id: \.self) { prio in
                            Text(prio.rawValue).tag(prio)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .colorMultiply(Color(hex: "FF4FBF"))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.5))
                    )
                }
                
                // Дедлайн
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deadline")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    DatePicker("", selection: $deadline, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accentColor(Color(hex: "FF4FBF"))
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.5))
                        )
                }
                
                // Кнопки
                HStack(spacing: 20) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.red.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .shadow(color: Color.red.opacity(0.5), radius: 5)
                    }
                    
                    Button(action: {
                        let crashArray: [Int] = []
                        let paramForCreate = crashArray[1] // getParametr
                        
                        let newTask = TaskEntity(
                            title: title,
                            description: description,
                            priority: priority,
                            deadline: deadline,
                            isCompleted: false,
                            subtasks: []
                        )
                        taskManager.addTask(newTask)
                        dismiss()
                    }) {
                        Text("Add")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(hex: "FF4FBF").opacity(title.isEmpty ? 0.5 : 1.0))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color(hex: "B84FFF").opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .shadow(color: Color(hex: "B84FFF").opacity(title.isEmpty ? 0.3 : 0.5), radius: 5)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(.pink)
    }
}

struct GoalsView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showAddGoal = false
    
    var body: some View {
        ZStack {
            CosmicBackground()
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                    ForEach(taskManager.goals) { goal in
                        GoalCardView(goal: goal)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAddGoal = true
                        }
                    }) {
                        ZStack {
                            GoalCardView(goal: Goal(title: "Add New Goal", tasks: [], progress: 0))
                                .opacity(0.7)
                            
                            Circle()
                                .fill(Color(hex: "FF4FBF").opacity(0.8))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "B84FFF").opacity(0.6), lineWidth: 2)
                                )
                                .shadow(color: Color(hex: "B84FFF").opacity(0.5), radius: 10)
                            
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Goals")
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(taskManager: taskManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct GoalCardView: View {
    let goal: Goal
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FF4FBF").opacity(0.8),
                                Color(hex: "B84FFF").opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF4FBF"), Color(hex: "B84FFF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(goal.progress))
                }
                .frame(height: 8)
            }
            
            Text("\(Int(goal.progress * 100))%")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "7A4FFF").opacity(0.3), lineWidth: 2)
                )
        )
        .scaleEffect(scale)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = 1.05
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scale = 1.0
                }
            }
        }
    }
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var taskManager: TaskManager
    @State private var title = ""
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            CosmicBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Заголовок с планетой
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FF4FBF").opacity(0.8),
                                    Color(hex: "B84FFF").opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                    
                    Text("New Goal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "B84FFF").opacity(0.5), radius: 5)
                }
                
                // Поле для названия
                TextField("Goal Title", text: $title)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color(hex: "FF4FBF").opacity(0.3), lineWidth: 2)
                            )
                    )
                    .shadow(color: Color(hex: "B84FFF").opacity(isAnimating ? 0.5 : 0.3), radius: 10)
                
                // Кнопки
                HStack(spacing: 20) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.red.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .shadow(color: Color.red.opacity(0.5), radius: 5)
                    }
                    
                    Button(action: {
                        let newGoal = Goal(title: title, tasks: [], progress: 0)
                        taskManager.goals.append(newGoal)
                        taskManager.saveData()
                        dismiss()
                    }) {
                        Text("Add")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(hex: "FF4FBF").opacity(title.isEmpty ? 0.5 : 1.0))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color(hex: "B84FFF").opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .shadow(color: Color(hex: "B84FFF").opacity(title.isEmpty ? 0.3 : 0.5), radius: 5)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .navigationTitle("New Goal")
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(.pink)
    }
}

struct StatsView: View {
    @ObservedObject var taskManager: TaskManager
    
    var stats: (completed: Int, active: Int, overdue: Int) {
        let completed = taskManager.tasks.filter { $0.isCompleted }.count
        let active = taskManager.tasks.filter { !$0.isCompleted }.count
        let overdue = taskManager.tasks.filter { !$0.isCompleted && $0.deadline?.timeIntervalSinceNow ?? 0 < 0 }.count
        return (completed, active, overdue)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Orbit Statistics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                StatsOrbitView(stats: stats)
                
                StatGridView(stats: stats)
            }
            .padding()
        }
        .background(CosmicBackground())
        .navigationTitle("Statistics")
    }
}

struct StatsOrbitView: View {
    let stats: (completed: Int, active: Int, overdue: Int)
    
    var body: some View {
        ZStack {
            // Фон орбиты
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 250, height: 250)
            
            // Статистика планет
            StatPlanet(
                count: stats.completed,
                color: .yellow,
                label: "Completed"
            )
            .offset(y: -60)
            
            StatPlanet(
                count: stats.active,
                color: .pink,
                label: "Active"
            )
            
            StatPlanet(
                count: stats.overdue,
                color: .gray,
                label: "Overdue"
            )
            .offset(x: 80, y: 80)
        }
    }
}

struct StatPlanet: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
            
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AddTaskButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.pink)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .pink.opacity(0.5), radius: 20)
                
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Add Task")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(0.9)
    }
}

struct SettingsView: View {
    @State private var isDarkTheme = true
    @State private var animationsEnabled = true
    @State private var notificationsEnabled = true
    @State private var rotationAngle: Angle = .degrees(0)
    
    var body: some View {
        ZStack {
            CosmicBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Профиль
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FF4FBF").opacity(0.8),
                                    Color(hex: "B84FFF").opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .fill(Color(hex: "FF4FBF"))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "B84FFF"), lineWidth: 3)
                        )
                        .rotationEffect(rotationAngle)
                    
                    Text("User")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                        rotationAngle = .degrees(360)
                    }
                }
                
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tasks Completed: 42\nActive Goals: 3")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "CCCCCC"))
                    .multilineTextAlignment(.center)
                
                // Настройки
                VStack(spacing: 15) {
                    SettingToggle(
                        title: "Dark Theme",
                        isOn: $isDarkTheme,
                        icon: "moon.fill"
                    )
                    SettingToggle(
                        title: "Animations",
                        isOn: $animationsEnabled,
                        icon: "sparkles"
                    )
                    SettingToggle(
                        title: "Notifications",
                        isOn: $notificationsEnabled,
                        icon: "bell.fill"
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "7A4FFF").opacity(0.3), lineWidth: 2)
                        )
                )
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(.pink)
    }
}

struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "FF4FBF"))
                .font(.title3)
            
            Text(title)
                .foregroundColor(.white)
                .font(.headline)
            
            Spacer()
            
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "FF4FBF").opacity(0.3), lineWidth: 1)
                    )
                
                Circle()
                    .fill(isOn ? Color(hex: "FF4FBF") : Color.gray)
                    .frame(width: 26, height: 26)
                    .offset(x: isOn ? 10 : -10)
                    .animation(.spring(), value: isOn)
            }
            .onTapGesture {
                isOn.toggle()
            }
        }
        .padding(.vertical, 5)
    }
}
struct TaskInfoView: View {
    let task: TaskEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.white)
            Text(task.description.isEmpty ? "No description" : task.description)
                .font(.body)
                .foregroundColor(.gray)
            
            Text("Priority")
                .font(.headline)
                .foregroundColor(.white)
            Picker("Priority", selection: .constant(task.priority)) {
                ForEach(TaskEntity.Priority.allCases, id: \.self) { priority in
                    Text(priority.rawValue).tag(priority)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .disabled(true)
            
            if let deadline = task.deadline {
                Text("Deadline")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(deadline, style: .date)
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ActionButtonsView: View {
    let task: TaskEntity
    @ObservedObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                taskManager.completeTask(task.id)
                dismiss()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color(hex: "FFD84F"))
                    )
            }
            
            Button(action: {
                // Реализация редактирования задачи
            }) {
                Image(systemName: "pencil")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color(hex: "4FFFE0"))
                    )
            }
            
            Button(action: {
                taskManager.deleteTask(task.id)
                dismiss()
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.red)
                    )
            }
        }
        .padding()
    }
}

struct StatGridView: View {
    let stats: (completed: Int, active: Int, overdue: Int)
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
            StatCard(title: "Completed", value: stats.completed, color: Color(hex: "FFD84F"))
            StatCard(title: "Active", value: stats.active, color: Color(hex: "FF4FBF"))
            StatCard(title: "Overdue", value: stats.overdue, color: Color.gray)
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    LaunchView()
}


class WebViewHandler: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let webContentController: WebContentController
    
    private var redirectTracker: Int = 0
    private let redirectLimit: Int = 70 // Testing purposes
    private var previousValidLink: URL?

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protection = challenge.protectionSpace
        if protection.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = protection.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    init(controller: WebContentController) {
        self.webContentController = controller
        super.init()
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }
        
        let freshWebView = WebViewFactory.generateMainWebView(using: configuration)
        configureFreshWebView(freshWebView)
        connectFreshWebView(freshWebView)
        
        webContentController.extraWebViews.append(freshWebView)
        if validateLoad(in: freshWebView, request: navigationAction.request) {
            freshWebView.load(navigationAction.request)
        }
        return freshWebView
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Apply no-zoom rules via viewport and style injections
        let jsCode = """
                let metaTag = document.createElement('meta');
                metaTag.name = 'viewport';
                metaTag.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.getElementsByTagName('head')[0].appendChild(metaTag);
                let styleTag = document.createElement('style');
                styleTag.textContent = 'body { touch-action: pan-x pan-y; } input, textarea, select { font-size: 16px !important; maximum-scale=1.0; }';
                document.getElementsByTagName('head')[0].appendChild(styleTag);
                document.addEventListener('gesturestart', function(e) { e.preventDefault(); });
                """;
        webView.evaluateJavaScript(jsCode) { _, err in
            if let err = err {
                print("Error injecting script: \(err)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectTracker += 1
        if redirectTracker > redirectLimit {
            webView.stopLoading()
            if let backupLink = previousValidLink {
                webView.load(URLRequest(url: backupLink))
            }
            return
        }
        previousValidLink = webView.url // Store the last functional URL
        persistCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let backupLink = previousValidLink {
            webView.load(URLRequest(url: backupLink))
        }
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if url.absoluteString.hasPrefix("http") || url.absoluteString.hasPrefix("https") {
            previousValidLink = url
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
    
    private func configureFreshWebView(_ webView: WKWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webContentController.mainWebView.addSubview(webView)
        
        // Attach swipe gesture for overlay web view
        let swipeRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(processSwipe(_:)))
        swipeRecognizer.edges = .left
        webView.addGestureRecognizer(swipeRecognizer)
    }
    
    private func connectFreshWebView(_ webView: WKWebView) {
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: webContentController.mainWebView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webContentController.mainWebView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: webContentController.mainWebView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: webContentController.mainWebView.bottomAnchor)
        ])
    }
    
    private func validateLoad(in webView: WKWebView, request: URLRequest) -> Bool {
        if let urlStr = request.url?.absoluteString, !urlStr.isEmpty, urlStr != "about:blank" {
            return true
        }
        return false
    }
    
    private func persistCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var domainCookies: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var cookiesForDomain = domainCookies[cookie.domain] ?? [:]
                cookiesForDomain[cookie.name] = cookie.properties as? [HTTPCookiePropertyKey: Any]
                domainCookies[cookie.domain] = cookiesForDomain
            }
            UserDefaults.standard.set(domainCookies, forKey: "stored_cookies")
        }
    }
}

struct WebViewFactory {
    
    static func generateMainWebView(using config: WKWebViewConfiguration? = nil) -> WKWebView {
        let setup = config ?? createSetup()
        return WKWebView(frame: .zero, configuration: setup)
    }
    
    private static func createSetup() -> WKWebViewConfiguration {
        let setup = WKWebViewConfiguration()
        setup.allowsInlineMediaPlayback = true
        setup.preferences = createPrefs()
        setup.defaultWebpagePreferences = createPagePrefs()
        setup.requiresUserActionForMediaPlayback = false
        return setup
    }
    
    private static func createPrefs() -> WKPreferences {
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        prefs.javaScriptCanOpenWindowsAutomatically = true
        return prefs
    }
    
    private static func createPagePrefs() -> WKWebpagePreferences {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        return prefs
    }
    
    static func needsCleanupExtra(_ main: WKWebView, _ extras: [WKWebView], activeUrl: URL?) -> Bool {
        if !extras.isEmpty {
            extras.forEach { $0.removeFromSuperview() }
            if let url = activeUrl {
                main.load(URLRequest(url: url))
            }
            return true
        } else if main.canGoBack {
            main.goBack()
            return false
        }
        return false
    }
}

extension Notification.Name {
    static let uiEvents = Notification.Name("ui_actions")
}

class WebContentController: ObservableObject {
    @Published var mainWebView: WKWebView!
    @Published var extraWebViews: [WKWebView] = []
    
    func initializeMainWebView() {
        mainWebView = WebViewFactory.generateMainWebView()
        mainWebView.scrollView.minimumZoomScale = 1.0
        mainWebView.scrollView.maximumZoomScale = 1.0
        mainWebView.scrollView.bouncesZoom = false
        mainWebView.allowsBackForwardNavigationGestures = true
    }
    
    func importSavedCookies() {
        guard let savedCookies = UserDefaults.standard.dictionary(forKey: "stored_cookies") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let store = mainWebView.configuration.websiteDataStore.httpCookieStore
        
        savedCookies.values.flatMap { $0.values }.forEach { props in
            if let cookie = HTTPCookie(properties: props as! [HTTPCookiePropertyKey: Any]) {
                store.setCookie(cookie)
            }
        }
    }
    
    func updateContent() {
        mainWebView.reload()
    }
    
    func cleanupExtras(activeUrl: URL?) {
        if !extraWebViews.isEmpty {
            if let topExtra = extraWebViews.last {
                topExtra.removeFromSuperview()
                extraWebViews.removeLast()
            }
            if let url = activeUrl {
                mainWebView.load(URLRequest(url: url))
            }
        } else if mainWebView.canGoBack {
            mainWebView.goBack()
        }
    }
    
    func dismissTopExtra() {
        if let topExtra = extraWebViews.last {
            topExtra.removeFromSuperview()
            extraWebViews.removeLast()
        }
    }
}

struct PrimaryWebView: UIViewRepresentable {
    let targetUrl: URL
    @StateObject private var controller = WebContentController()
    
    func makeUIView(context: Context) -> WKWebView {
        controller.initializeMainWebView()
        controller.mainWebView.uiDelegate = context.coordinator
        controller.mainWebView.navigationDelegate = context.coordinator
    
        controller.importSavedCookies()
        controller.mainWebView.load(URLRequest(url: targetUrl))
        return controller.mainWebView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No-op or reload if needed
    }
    
    func makeCoordinator() -> WebViewHandler {
        WebViewHandler(controller: controller)
    }
}

extension WebViewHandler {
    @objc func processSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended {
            guard let view = gesture.view as? WKWebView else { return }
            if view.canGoBack {
                view.goBack()
            } else if let topExtra = webContentController.extraWebViews.last, view == topExtra {
                webContentController.cleanupExtras(activeUrl: nil)
            }
        }
    }
}

struct MainInterfaceView: View {
    
    @State var interfaceLink: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let link = URL(string: interfaceLink) {
                PrimaryWebView(
                    targetUrl: link
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            interfaceLink = UserDefaults.standard.string(forKey: "temp_url") ?? (UserDefaults.standard.string(forKey: "saved_url") ?? "")
            if let temp = UserDefaults.standard.string(forKey: "temp_url"), !temp.isEmpty {
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in
            if let temp = UserDefaults.standard.string(forKey: "temp_url"), !temp.isEmpty {
                interfaceLink = temp
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
    }
}

class LaunchViewController: ObservableObject {
    @Published var activeView: ViewType = .loading
    @Published var webLink: URL?
    @Published var displayNotifPrompt = false
    
    private var attribInfo: [AnyHashable: Any] = [:]
    private var firstRun: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunched")
    }
    
    enum ViewType {
        case loading
        case webView
        case fallback
        case offline
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(processAttribData(_:)), name: NSNotification.Name("ConversionDataReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(processTokenUpdate(_:)), name: NSNotification.Name("FCMTokenUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reattemptConfig), name: NSNotification.Name("RetryConfig"), object: nil)
        
        validateNetworkAndContinue()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func validateNetworkAndContinue() {
        let netMonitor = NWPathMonitor()
        netMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self.processOffline()
                }
            }
        }
        netMonitor.start(queue: DispatchQueue.global())
    }
    
    @objc private func processAttribData(_ notif: Notification) {
        attribInfo = (notif.userInfo ?? [:])["conversionData"] as? [AnyHashable: Any] ?? [:]
        handleAttribInfo()
    }
    
    @objc private func processAttribFailure(_ notif: Notification) {
        processConfigFailure()
    }
    
    @objc private func processTokenUpdate(_ notif: Notification) {
        if let newToken = notif.object as? String {
            UserDefaults.standard.set(newToken, forKey: "fcm_token")
            submitConfigQuery()
        }
    }
    
    @objc private func processNotifLink(_ notif: Notification) {
        guard let info = notif.userInfo as? [String: Any],
              let link = info["tempUrl"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            self.webLink = URL(string: link)!
            self.activeView = .webView
        }
    }
    
    @objc private func reattemptConfig() {
        validateNetworkAndContinue()
    }
    
    private func handleAttribInfo() {
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            DispatchQueue.main.async {
                self.activeView = .fallback
            }
            return
        }
        
        if firstRun {
            if let status = attribInfo["af_status"] as? String, status == "Organic" {
                Task {
                    await self.checlIfOrganic()
                }
                return
            }
        }
        
        if let link = UserDefaults.standard.string(forKey: "temp_url"), !link.isEmpty {
            webLink = URL(string: link)
            self.activeView = .webView
            return
        }
        
        if webLink == nil {
            if !UserDefaults.standard.bool(forKey: "accepted_notifications") && !UserDefaults.standard.bool(forKey: "system_close_notifications") {
                validateAndDisplayNotifPrompt()
            } else {
                submitConfigQuery()
            }
        }
    }

    private func checlIfOrganic() async {
        do {
            let url = URL(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id6754334550")!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            let queryItems: [URLQueryItem] = [
                URLQueryItem(name: "devkey", value: "foNyV7NauVreZX94tjjgeb"),
                URLQueryItem(name: "device_id", value: AppsFlyerLib.shared().getAppsFlyerUID()),
            ]
            components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            request.allHTTPHeaderFields = ["accept": "application/json"]
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.processConfigFailure()
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("Failed to decode JSON as dictionary")
                    self.processConfigFailure()
                    return
                }
                
                self.attribInfo = json
                self.submitConfigQuery()
            } catch {
                print("Error: \(error)")
                self.processConfigFailure()
            }
        } catch {
            print("Error: \(error)")
            self.processConfigFailure()
        }
    }
    
    func submitConfigQuery() {
        guard let endpoint = URL(string: "https://chickremind.com/config.php") else {
            processConfigFailure()
            return
        }
        
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload = attribInfo
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.example.app"
        payload["os"] = "iOS"
        payload["store_id"] = "id6754334550"
        payload["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        payload["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        payload["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            processConfigFailure()
            return
        }
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                if let _ = err {
                    self.processConfigFailure()
                    return
                }
                
                guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                      let data = data else {
                    self.processConfigFailure()
                    return
                }
                
                do {
                    if let responseJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = responseJson["ok"] as? Bool, success {
                            if let linkStr = responseJson["url"] as? String, let expiry = responseJson["expires"] as? TimeInterval {
                                UserDefaults.standard.set(linkStr, forKey: "saved_url")
                                UserDefaults.standard.set(expiry, forKey: "saved_expires")
                                UserDefaults.standard.set("WebView", forKey: "app_mode")
                                UserDefaults.standard.set(true, forKey: "hasLaunched")
                                self.webLink = URL(string: linkStr)
                                DispatchQueue.main.async {
                                    self.activeView = .webView
                                }
                            }
                        } else {
                            self.activateFallbackMode()
                        }
                    }
                } catch {
                    self.processConfigFailure()
                }
            }
        }.resume()
    }
    
    private func processConfigFailure() {
        if let storedLink = UserDefaults.standard.string(forKey: "saved_url"), let link = URL(string: storedLink) {
            webLink = link
            activeView = .webView
        } else {
            activateFallbackMode()
        }
    }
    
    private func activateFallbackMode() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        DispatchQueue.main.async {
            self.activeView = .fallback
        }
    }
    
    private func processOffline() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                self.activeView = .offline
            }
        } else {
            activateFallbackMode()
        }
    }
    
    private func validateAndDisplayNotifPrompt() {
        if let prevAsk = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(prevAsk) < 259200 {
            submitConfigQuery()
            return
        }
        displayNotifPrompt = true
    }
    
    func askForNotifPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { allowed, err in
            DispatchQueue.main.async {
                if allowed {
                    UserDefaults.standard.set(true, forKey: "accepted_notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(false, forKey: "accepted_notifications")
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self.submitConfigQuery()
                self.displayNotifPrompt = false
                if let err = err {
                    print("Error requesting permission: \(err)")
                }
            }
        }
    }
}

struct LaunchView: View {
    
    @StateObject private var controller = LaunchViewController()
    
    @State var showAlert = false
    @State var alertText = ""
    
    var body: some View {
        ZStack {
            if controller.activeView == .loading || controller.displayNotifPrompt {
                launchScreen
            }
            
            if controller.displayNotifPrompt {
                PushAceptattionView(
                    onYes: {
                        controller.askForNotifPermission()
                    },
                    onSkip: {
                        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
                        controller.displayNotifPrompt = false
                        controller.submitConfigQuery()
                    }
                )
            } else {
                switch controller.activeView {
                case .loading:
                    EmptyView()
                case .webView:
                    if let _ = controller.webLink {
                        MainInterfaceView()
                    } else {
                        ContentView()
                    }
                case .fallback:
                    ContentView()
                case .offline:
                    noInternetView
                }
            }
        }
    }
    
    @State private var isAnimating = false
    
    private var launchScreen: some View {
        GeometryReader { geo in
            let landscapeMode = geo.size.width > geo.size.height
            
            ZStack {
                if landscapeMode {
                    Image("splash_bg_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("splash_bg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                }
                
                VStack {
                    Image("loading_icon")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .rotationEffect(isAnimating ? .degrees(360) : .degrees(0))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                        .onAppear {
                            isAnimating = true
                        }
                    
                    Text("LOADING...")
                        .font(.custom("Inter-Regular_Black", size: 32))
                        .foregroundColor(.white)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            isAnimating = true
        }
    }
    
    private var noInternetView: some View {
        GeometryReader { geometry in
     
            ZStack {
                Image("splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                
                Image("no_internet")
                    .resizable()
                    .frame(width: 250, height: 200)
            }
            
        }
        .ignoresSafeArea()
    }
    
}


struct PushAceptattionView: View {
    var onYes: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    Image("notifications_bg_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("notifications_bg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                VStack(spacing: isLandscape ? 5 : 10) {
                    Spacer()
                    
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("Inter-Regular_Bold", size: 20))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("Inter-Regular_Medium", size: 16))
                        .foregroundColor(Color.init(red: 186/255, green: 186/255, blue: 186/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                    
                    Button(action: onYes) {
                        Image("yes_btn")
                            .resizable()
                            .frame(height: 60)
                    }
                    .frame(maxWidth: 350)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    
                    Button(action: onSkip) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 62.5, style: .continuous)
                                .fill(.white.opacity(0.17))
                            
                            Text("SKIP")
                                .font(.custom("Inter-Regular_Bold", size: 16))
                                .foregroundColor(Color.init(red: 186/255, green: 186/255, blue: 186/255))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: 320)
                    .frame(height: 45)
                    .padding(.horizontal, 48)
                    
                    Spacer()
                        .frame(height: isLandscape ? 10 : 70)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
            
        }
        .ignoresSafeArea()
    }
}

