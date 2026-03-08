import CalendarTodoCore
import SwiftData
import SwiftUI

struct CalendarContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var calendarVM = CalendarViewModel()
    @State private var eventVM = EventViewModel()
    @State private var showEventEdit = false
    @State private var selectedEvent: LocalEvent?
    @State private var showEventDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode picker
                Picker("뷰", selection: $calendarVM.viewMode) {
                    ForEach(CalendarViewModel.CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .onChange(of: calendarVM.viewMode) { _, _ in
                    calendarVM.refreshEvents()
                }

                // Calendar views
                switch calendarVM.viewMode {
                case .month:
                    CalendarMonthView(viewModel: calendarVM)
                case .week:
                    CalendarWeekView(viewModel: calendarVM) { event in
                        selectedEvent = event
                        showEventDetail = true
                    }
                case .day:
                    CalendarDayView(viewModel: calendarVM) { event in
                        selectedEvent = event
                        showEventDetail = true
                    }
                }

                Spacer()
            }
            .navigationTitle("캘린더")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        eventVM.reset()
                        eventVM.startDate = calendarVM.selectedDate
                        eventVM.endDate = calendarVM.selectedDate.addingTimeInterval(3600)
                        showEventEdit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        calendarVM.goToToday()
                    } label: {
                        Text("오늘")
                    }
                }
            }
            .sheet(isPresented: $showEventEdit) {
                calendarVM.refreshEvents()
            } content: {
                EventEditView(viewModel: eventVM)
            }
            .sheet(isPresented: $showEventDetail) {
                if let event = selectedEvent {
                    NavigationStack {
                        EventDetailView(
                            event: event,
                            onEdit: {
                                showEventDetail = false
                                eventVM.loadEvent(event)
                                showEventEdit = true
                            },
                            onDelete: {
                                eventVM.setup(modelContext: modelContext)
                                eventVM.loadEvent(event)
                                eventVM.deleteEvent()
                                showEventDetail = false
                                calendarVM.refreshEvents()
                            }
                        )
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                calendarVM.setup(modelContext: modelContext)
                eventVM.setup(modelContext: modelContext)
            }
        }
    }
}
