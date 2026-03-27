import Foundation

/// Centralized localization strings for Korean, English, Japanese, Chinese
enum L10n {
    // MARK: - Language detection

    private enum Lang {
        case ko, en, ja, zh
    }

    private static var current: Lang {
        let lang = Locale.preferredLanguages.first ?? "en"
        if lang.hasPrefix("ko") { return .ko }
        if lang.hasPrefix("ja") { return .ja }
        if lang.hasPrefix("zh") { return .zh }
        return .en
    }

    private static func tr(_ ko: String, _ en: String, _ ja: String? = nil, _ zh: String? = nil) -> String {
        switch current {
        case .ko: return ko
        case .en: return en
        case .ja: return ja ?? en
        case .zh: return zh ?? en
        }
    }

    // MARK: - Common
    static var cancel: String { tr("취소", "Cancel", "キャンセル", "取消") }
    static var save: String { tr("저장", "Save", "保存", "保存") }
    static var delete: String { tr("삭제", "Delete", "削除", "删除") }
    static var done: String { tr("완료", "Done", "完了", "完成") }
    static var edit: String { tr("수정", "Edit", "編集", "编辑") }
    static var loading: String { tr("로딩 중...", "Loading...", "読み込み中...", "加载中...") }
    static var today: String { tr("오늘", "Today", "今日", "今天") }
    static var select: String { tr("선택", "Select", "選択", "选择") }
    static var systemDefault: String { tr("시스템 기본", "System Default", "システムデフォルト", "系统默认") }
    static var titleRequired: String { tr("제목을 입력해주세요.", "Please enter a title.", "タイトルを入力してください。", "请输入标题。") }
    static var endAfterStart: String { tr("종료 시간이 시작 시간보다 이후여야 합니다.", "End time must be after start time.", "終了時刻は開始時刻より後でなければなりません。", "结束时间必须在开始时间之后。") }
    static var next: String { tr("다음", "Next", "次へ", "下一步") }
    static var getStarted: String { tr("시작하기", "Get Started", "始める", "开始") }

    // MARK: - Tabs
    static var calendarTab: String { tr("캘린더", "Calendar", "カレンダー", "日历") }
    static var dailyTodoTab: String { tr("오늘 할 일", "Daily Todo", "今日のタスク", "今日待办") }
    static var weeklyTodoTab: String { tr("주간 할 일", "Weekly Todo", "週間タスク", "本周待办") }
    static var socialTab: String { tr("친구", "Friends", "友達", "好友") }
    static var settingsTab: String { tr("설정", "Settings", "設定", "设置") }

    // MARK: - Calendar
    static var noEvents: String { tr("일정 없음", "No events", "予定なし", "无日程") }
    static var noEventsForDay: String { tr("이 날의 일정이 없습니다", "No events for this day", "この日の予定はありません", "这一天没有日程") }
    static var allDay: String { tr("종일", "All day", "終日", "全天") }

    // MARK: - Week day headers
    static var weekDayMon: String { tr("월", "Mon", "月", "一") }
    static var weekDayTue: String { tr("화", "Tue", "火", "二") }
    static var weekDayWed: String { tr("수", "Wed", "水", "三") }
    static var weekDayThu: String { tr("목", "Thu", "木", "四") }
    static var weekDayFri: String { tr("금", "Fri", "金", "五") }
    static var weekDaySat: String { tr("토", "Sat", "土", "六") }
    static var weekDaySun: String { tr("일", "Sun", "日", "日") }

    static var weekDayHeaders: [String] {
        [weekDayMon, weekDayTue, weekDayWed, weekDayThu, weekDayFri, weekDaySat, weekDaySun]
    }

    static var shortDayNames: [String] {
        weekDayHeaders
    }

    // MARK: - Event Edit
    static var title: String { tr("제목", "Title", "タイトル", "标题") }
    static var descriptionOptional: String { tr("설명 (선택)", "Description (optional)", "説明（任意）", "描述（可选）") }
    static var timeSection: String { tr("시간", "Time", "時間", "时间") }
    static var startTime: String { tr("시작", "Start", "開始", "开始") }
    static var endTime: String { tr("종료", "End", "終了", "结束") }
    static var locationSection: String { tr("위치", "Location", "場所", "位置") }
    static var addLocation: String { tr("위치 추가", "Add Location", "場所を追加", "添加位置") }
    static var alarmSection: String { tr("알람", "Alarm", "アラーム", "提醒") }
    static var addAlarm: String { tr("알람 추가", "Add Alarm", "アラームを追加", "添加提醒") }
    static var recurrenceSection: String { tr("반복", "Repeat", "繰り返し", "重复") }
    static var recurrence: String { tr("반복", "Repeat", "繰り返し", "重复") }
    static var recurrenceRule: String { tr("반복 규칙", "Repeat Rule", "繰り返しルール", "重复规则") }
    static var doesNotRepeat: String { tr("반복 안 함", "Does Not Repeat", "繰り返しなし", "不重复") }
    static var deleteEvent: String { tr("일정 삭제", "Delete Schedule", "予定を削除", "删除日程") }
    static var editEvent: String { tr("일정 수정", "Edit Schedule", "予定を編集", "编辑日程") }
    static var newEvent: String { tr("새 일정", "New Schedule", "新しい予定", "新建日程") }
    static var deleteEventConfirm: String { tr("일정을 삭제하시겠습니까?", "Delete this schedule?", "この予定を削除しますか？", "确定删除此日程？") }
    static var scheduleColor: String { tr("일정 색상", "Schedule Color", "予定の色", "日程颜色") }

    // MARK: - Recurring Delete Options
    static var deleteRecurringTitle: String { tr("반복 일정 삭제", "Delete Recurring Schedule", "繰り返し予定の削除", "删除重复日程") }
    static var deleteThisOnly: String { tr("이 일정만 삭제", "Delete This Only", "この予定のみ削除", "仅删除此日程") }
    static var deleteThisAndFuture: String { tr("이후 일정도 모두 삭제", "Delete This & Future", "これ以降の予定も削除", "删除此日程及之后的") }
    static var deleteAll: String { tr("모든 반복 일정 삭제", "Delete All", "すべての繰り返しを削除", "删除所有重复日程") }

    // MARK: - Alarm labels
    static var atEventTime: String { tr("일정 시간", "At event time", "予定の時間", "日程时间") }
    static var selectAlarm: String { tr("알람 선택", "Select Alarm", "アラームを選択", "选择提醒") }

    static func minutesBefore(_ m: Int) -> String { tr("\(m)분 전", "\(m) min before", "\(m)分前", "\(m)分钟前") }
    static func hoursBefore(_ h: Int) -> String { tr("\(h)시간 전", "\(h) hr before", "\(h)時間前", "\(h)小时前") }
    static func daysBefore(_ d: Int) -> String { tr("\(d)일 전", "\(d) day before", "\(d)日前", "\(d)天前") }
    static func weeksBefore(_ w: Int) -> String { tr("\(w)주일 전", "\(w) week before", "\(w)週間前", "\(w)周前") }
    static func monthsBefore(_ m: Int) -> String { tr("\(m)개월 전", "\(m) month before", "\(m)ヶ月前", "\(m)个月前") }

    static func alarmLabel(minutes: Int) -> String {
        switch minutes {
        case 0: return atEventTime
        case 10: return minutesBefore(10)
        case 30: return minutesBefore(30)
        case 60: return hoursBefore(1)
        case 120: return hoursBefore(2)
        case 1440: return daysBefore(1)
        case 10080: return weeksBefore(1)
        case 20160: return weeksBefore(2)
        case 43200: return monthsBefore(1)
        default: return minutesBefore(minutes)
        }
    }

    // MARK: - Recurrence
    static var daily: String { tr("매일", "Daily", "毎日", "每天") }
    static var weekly: String { tr("매주", "Weekly", "毎週", "每周") }
    static var monthly: String { tr("매달", "Monthly", "毎月", "每月") }
    static var yearly: String { tr("매년", "Yearly", "毎年", "每年") }
    static var recurrenceCycle: String { tr("반복 주기", "Repeat Cycle", "繰り返し周期", "重复周期") }
    static var cycle: String { tr("주기", "Cycle", "周期", "周期") }
    static var interval: String { tr("간격", "Interval", "間隔", "间隔") }
    static var selectDays: String { tr("요일 선택", "Select Days", "曜日を選択", "选择星期") }
    static var weekdays: String { tr("평일", "Weekdays", "平日", "工作日") }
    static var weekends: String { tr("주말", "Weekends", "週末", "周末") }
    static var everyday: String { tr("매일", "Everyday", "毎日", "每天") }
    static var endSection: String { tr("종료", "End", "終了", "结束") }
    static var setEndDate: String { tr("종료 날짜 설정", "Set End Date", "終了日を設定", "设置结束日期") }
    static var endDate: String { tr("종료 날짜", "End Date", "終了日", "结束日期") }

    // MARK: - Location
    static var searchLocation: String { tr("장소 검색", "Search Places", "場所を検索", "搜索地点") }
    static var unknownPlace: String { tr("알 수 없는 장소", "Unknown place", "不明な場所", "未知地点") }
    static var locationSearch: String { tr("위치 검색", "Location Search", "場所検索", "位置搜索") }

    // MARK: - Auth
    static var calendarAndTodo: String { tr("캘린더와 할 일을 한 곳에서", "Calendar and todos in one place", "カレンダーとタスクをひとつに", "日历与待办，一站搞定") }
    static var signInWithGoogle: String { tr("Google로 로그인", "Sign in with Google", "Googleでログイン", "使用Google登录") }
    static var appleCredentialError: String { tr("Apple 인증 정보를 가져올 수 없습니다.", "Could not get Apple credentials.", "Apple認証情報を取得できません。", "无法获取Apple凭证。") }
    static func signInFailed(_ error: String) -> String { tr("로그인에 실패했습니다: \(error)", "Sign in failed: \(error)", "ログインに失敗しました: \(error)", "登录失败: \(error)") }
    static func appleSignInFailed(_ error: String) -> String { tr("Apple 로그인 실패: \(error)", "Apple sign in failed: \(error)", "Appleログイン失敗: \(error)", "Apple登录失败: \(error)") }
    static var authInvalidCredentials: String { tr("이메일 또는 비밀번호가 올바르지 않습니다.", "Invalid email or password.", "メールアドレスまたはパスワードが正しくありません。", "邮箱或密码不正确。") }
    static var authUserNotFound: String { tr("등록되지 않은 계정입니다.", "Account not found.", "アカウントが見つかりません。", "未找到该账号。") }
    static var authEmailTaken: String { tr("이미 가입된 이메일입니다.", "This email is already registered.", "このメールアドレスは既に登録されています。", "该邮箱已注册。") }
    static var authWeakPassword: String { tr("비밀번호는 6자 이상이어야 합니다.", "Password must be at least 6 characters.", "パスワードは6文字以上必要です。", "密码至少需要6个字符。") }
    static var authInvalidEmail: String { tr("올바른 이메일 형식이 아닙니다.", "Invalid email format.", "メールアドレスの形式が正しくありません。", "邮箱格式不正确。") }
    static var authTooManyRequests: String { tr("요청이 너무 많습니다. 잠시 후 다시 시도해주세요.", "Too many requests. Please try again later.", "リクエストが多すぎます。しばらくしてからお試しください。", "请求过多，请稍后再试。") }

    // MARK: - Profile Setup
    static var userId: String { tr("사용자 아이디", "Username", "ユーザーID", "用户名") }
    static var available: String { tr("사용 가능", "Available", "利用可能", "可用") }
    static var alreadyInUse: String { tr("이미 사용 중", "Already in use", "使用中", "已被使用") }
    static var usernameRules: String { tr("3~20자, 영문 소문자, 숫자, 밑줄만 가능", "3-20 chars, lowercase, numbers, underscore only", "3〜20文字、英小文字・数字・アンダースコアのみ", "3-20位，仅限小写字母、数字、下划线") }
    static var displayName: String { tr("표시 이름", "Display Name", "表示名", "显示名称") }
    static var displayNamePlaceholder: String { tr("이름", "Name", "名前", "名字") }
    static var checkUsername: String { tr("아이디 확인", "Check Username", "ID確認", "检查用户名") }
    static func checkFailed(_ error: String) -> String { tr("확인 실패: \(error)", "Check failed: \(error)", "確認失敗: \(error)", "检查失败: \(error)") }
    static func profileCreateFailed(_ error: String) -> String { tr("프로필 생성 실패: \(error)", "Profile creation failed: \(error)", "プロフィール作成失敗: \(error)", "创建资料失败: \(error)") }
    static var profileSetup: String { tr("프로필 설정", "Profile Setup", "プロフィール設定", "设置资料") }

    // MARK: - Placeholders
    static var dailyTodoPlaceholder: String { tr("준비 중입니다", "Coming soon", "準備中です", "即将推出") }
    static var weeklyTodoPlaceholder: String { tr("준비 중입니다", "Coming soon", "準備中です", "即将推出") }
    static var socialPlaceholder: String { tr("준비 중입니다", "Coming soon", "準備中です", "即将推出") }
    static var settingsPlaceholder: String { tr("준비 중입니다", "Coming soon", "準備中です", "即将推出") }

    // MARK: - Onboarding
    static var welcomeTitle: String { tr("환영합니다!", "Welcome!", "ようこそ！", "欢迎！") }
    static var welcomeSubtitle: String { tr("시작하기 전에 몇 가지를 설정해주세요", "Let's set up a few things before we start", "始める前にいくつか設定しましょう", "开始之前，让我们先设置一些内容") }
    static var timeFormatTitle: String { tr("시간 형식", "Time Format", "時間形式", "时间格式") }
    static var timeFormatDescription: String { tr("시간을 어떻게 표시할까요?", "How would you like to display time?", "時間をどのように表示しますか？", "您想如何显示时间？") }
    static var dateFormatTitle: String { tr("날짜 형식", "Date Format", "日付形式", "日期格式") }
    static var dateFormatDescription: String { tr("날짜를 어떻게 표시할까요?", "How would you like to display dates?", "日付をどのように表示しますか？", "您想如何显示日期？") }
    static var time24h: String { tr("24시간제", "24-hour", "24時間制", "24小时制") }
    static var time12h: String { tr("12시간제", "12-hour (AM/PM)", "12時間制（AM/PM）", "12小时制（AM/PM）") }

    // MARK: - Settings
    static var settingsTitle: String { tr("설정", "Settings", "設定", "设置") }
    static var appearance: String { tr("표시 설정", "Display", "表示設定", "显示设置") }
    static var timeFormatSetting: String { tr("시간 형식", "Time Format", "時間形式", "时间格式") }
    static var dateFormatSetting: String { tr("날짜 형식", "Date Format", "日付形式", "日期格式") }

    // MARK: - Todo
    static var addTodoPlaceholder: String { tr("할 일 추가...", "Add todo...", "タスクを追加...", "添加待办...") }
    static var noTodosForDay: String { tr("이 날의 할 일이 없습니다", "No todos for this day", "この日のタスクはありません", "这一天没有待办") }
    static var completed: String { tr("완료됨", "Completed", "完了", "已完成") }
    static var editTodo: String { tr("할 일 수정", "Edit Todo", "タスクを編集", "编辑待办") }
    static var deleteTodo: String { tr("할 일 삭제", "Delete Todo", "タスクを削除", "删除待办") }
    static var deleteTodoConfirm: String { tr("할 일을 삭제하시겠습니까?", "Delete this todo?", "このタスクを削除しますか？", "确定删除此待办？") }
    static var dueDate: String { tr("마감일", "Due Date", "期限", "截止日期") }
    static var priorityNone: String { tr("없음", "None", "なし", "无") }
    static var priorityLow: String { tr("낮음", "Low", "低", "低") }
    static var priorityMedium: String { tr("보통", "Medium", "中", "中") }
    static var priorityHigh: String { tr("높음", "High", "高", "高") }
    static var thisWeek: String { tr("이번 주", "This Week", "今週", "本周") }
    static var moveToNextWeek: String { tr("다음 주로 이동", "Move to Next Week", "来週に移動", "移到下周") }
    static var unassign: String { tr("배정 해제", "Unassign", "割り当て解除", "取消分配") }
    static var unassigned: String { tr("미배정", "Unassigned", "未割り当て", "未分配") }
    static var priority: String { tr("우선순위", "Priority", "優先度", "优先级") }
    static var removeAlarm: String { tr("알람 해제", "Remove Alarm", "アラームを解除", "移除提醒") }

    // MARK: - Social
    static var friendList: String { tr("친구 목록", "Friends", "友達リスト", "好友列表") }
    static var friendRequests: String { tr("친구 요청", "Requests", "リクエスト", "好友请求") }
    static var friendSearch: String { tr("검색", "Search", "検索", "搜索") }
    static var addFriend: String { tr("친구 추가", "Add Friend", "友達追加", "添加好友") }
    static var accept: String { tr("수락", "Accept", "承認", "接受") }
    static var decline: String { tr("거절", "Decline", "拒否", "拒绝") }
    static var noFriends: String { tr("아직 친구가 없습니다", "No friends yet", "まだ友達がいません", "还没有好友") }
    static var noRequests: String { tr("받은 요청이 없습니다", "No pending requests", "リクエストはありません", "没有待处理的请求") }
    static var searchByUsername: String { tr("아이디로 검색", "Search by username", "ユーザー名で検索", "通过用户名搜索") }
    static var noSearchResults: String { tr("검색 결과가 없습니다", "No results found", "検索結果がありません", "未找到结果") }
    static var requestSent: String { tr("요청 보냄", "Request Sent", "リクエスト送信済み", "已发送请求") }
    static var inviteFriends: String { tr("친구 초대", "Invite Friends", "友達を招待", "邀请好友") }
    static var myTodoLists: String { tr("내 할 일 목록", "My Todo Lists", "マイタスクリスト", "我的待办列表") }
    static var friendsTodoLists: String { tr("친구 할 일 목록", "Friends' Todo Lists", "友達のタスクリスト", "好友的待办列表") }
    static var newCategory: String { tr("새 카테고리", "New Category", "新しいカテゴリ", "新建分类") }
    static var categoryName: String { tr("카테고리 이름", "Category Name", "カテゴリ名", "分类名称") }
    static var categoryNamePlaceholder: String { tr("예: 운동, 공부, 업무", "e.g. Exercise, Study, Work", "例: 運動、勉強、仕事", "例如：运动、学习、工作") }
    static var visibility: String { tr("공개 설정", "Visibility", "公開設定", "可见性") }
    static var publicToFriends: String { tr("친구 공개", "Friends", "友達に公開", "好友可见") }
    static var privateOnly: String { tr("나만 보기", "Private", "自分のみ", "仅自己") }
    static var noCategoriesYet: String { tr("카테고리를 추가해보세요", "Add a category to get started", "カテゴリを追加しましょう", "添加一个分类开始吧") }
    static var uncategorized: String { tr("미분류", "Uncategorized", "未分類", "未分类") }
    static var comingSoon: String { tr("준비 중입니다", "Coming soon", "準備中です", "即将推出") }
    static var noSharedLists: String { tr("공유된 할 일 목록이 없습니다", "No shared lists yet", "共有リストはまだありません", "还没有共享列表") }
    static var pendingAssignments: String { tr("받은 할 일", "Assigned to you", "割り当てられたタスク", "分配给你的待办") }
    static var assignToFriend: String { tr("친구에게 할 일 보내기", "Assign to friend", "友達にタスクを送る", "分配给好友") }
    static var eventInvitationTitle: String { tr("일정 초대", "Event Invitation", "予定への招待", "日程邀请") }
    static var calendarSync: String { tr("캘린더 연동", "Calendar Sync", "カレンダー連携", "日历同步") }
    static var syncAppleCalendar: String { tr("Apple 캘린더 연동", "Sync with Apple Calendar", "Appleカレンダーと連携", "与Apple日历同步") }
    static var calendarSyncTitle: String { tr("캘린더 연동", "Sync Your Calendar", "カレンダー連携", "同步日历") }
    static var calendarSyncDescription: String { tr("Apple 캘린더의 일정을 가져오고\n새 일정을 자동으로 추가합니다", "Import events from Apple Calendar\nand automatically add new ones", "Appleカレンダーの予定を取得し\n新しい予定を自動的に追加します", "导入Apple日历的日程\n并自动添加新日程") }
    static var maybeLater: String { tr("나중에", "Maybe Later", "後で", "以后再说") }
    static var deleteCategoryConfirm: String { tr("카테고리와 모든 할 일을 삭제하시겠습니까?", "Delete category and all its todos?", "カテゴリとすべてのタスクを削除しますか？", "确定删除分类及其所有待办？") }
    static func friendAddedTodo(_ username: String, _ todoTitle: String) -> String {
        tr("@\(username) 님이 '\(todoTitle)'을(를) 오늘의 할 일에 추가했습니다",
           "@\(username) added '\(todoTitle)' to your todos",
           "@\(username) さんが「\(todoTitle)」をタスクに追加しました",
           "@\(username) 将「\(todoTitle)」添加到了你的待办")
    }
    static var alreadyFriends: String { tr("친구", "Friends", "友達", "好友") }
    static var participants: String { tr("참여자", "Participants", "参加者", "参与者") }
    static var removeFriendConfirm: String { tr("정말 친구를 삭제하시겠습니까?", "Remove this friend?", "この友達を削除しますか？", "确定要删除这个好友吗？") }

    // MARK: - Notification Messages
    static func friendRequestMessage(_ username: String) -> String {
        tr("@\(username) 님이 친구 요청을 보냈습니다",
           "@\(username) sent you a friend request",
           "@\(username) さんから友達リクエストが届きました",
           "@\(username) 向你发送了好友请求")
    }
    static func friendAcceptedMessage(_ username: String) -> String {
        tr("@\(username) 님이 친구 요청을 수락했습니다",
           "@\(username) accepted your friend request",
           "@\(username) さんが友達リクエストを承認しました",
           "@\(username) 接受了你的好友请求")
    }
    static func eventInvitationMessage(_ username: String, _ eventTitle: String) -> String {
        tr("@\(username) 님이 '\(eventTitle)' 일정에 초대했습니다",
           "@\(username) invited you to '\(eventTitle)'",
           "@\(username) さんが「\(eventTitle)」に招待しました",
           "@\(username) 邀请你参加「\(eventTitle)」")
    }
    static func todoAssignedMessage(_ username: String, _ todoTitle: String) -> String {
        tr("@\(username) 님이 '\(todoTitle)' 할 일을 보냈습니다",
           "@\(username) assigned '\(todoTitle)' to you",
           "@\(username) さんが「\(todoTitle)」を割り当てました",
           "@\(username) 给你分配了「\(todoTitle)」")
    }

    // MARK: - Account
    static var account: String { tr("계정", "Account", "アカウント", "账户") }
    static var loginInfo: String { tr("로그인 정보", "Login Info", "ログイン情報", "登录信息") }
    static var logout: String { tr("로그아웃", "Log Out", "ログアウト", "退出登录") }
    static var logoutConfirm: String { tr("로그아웃 하시겠습니까?", "Are you sure you want to log out?", "ログアウトしますか？", "确定要退出登录吗？") }
    static var deleteAccount: String { tr("계정 삭제", "Delete Account", "アカウント削除", "删除账户") }
    static var deleteAccountConfirm: String { tr("정말 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.", "Are you sure? This cannot be undone.", "本当に削除しますか？この操作は取り消せません。", "确定要删除账户吗？此操作无法撤销。") }
    static var deleteAccountWarning: String { tr("계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.", "Deleting your account will permanently remove all data.", "アカウントを削除するとすべてのデータが完全に削除されます。", "删除账户将永久删除所有数据。") }

    // MARK: - Ad Removal
    static var removeAds: String { tr("광고 제거", "Remove Ads", "広告を削除", "移除广告") }
    static var removeAdsDescription: String { tr("모든 광고를 영구적으로 제거합니다", "Remove all ads permanently", "すべての広告を永久に削除します", "永久移除所有广告") }
    static var removeAdsCompleted: String { tr("광고가 제거되었습니다", "Ads removed", "広告が削除されました", "广告已移除") }
    static var restorePurchase: String { tr("구매 복원", "Restore Purchase", "購入を復元", "恢复购买") }

    // MARK: - Email Auth
    static var emailConfirmationTitle: String { tr("이메일을 확인해주세요", "Check your email", "メールを確認してください", "请查看您的邮箱") }
    static func emailConfirmationMessage(_ email: String) -> String { tr("\(email)로 인증 메일을 보냈습니다.\n메일의 링크를 클릭하여 가입을 완료해주세요.", "We sent a verification email to \(email).\nClick the link to complete your sign up.", "\(email)に確認メールを送信しました。\nリンクをクリックして登録を完了してください。", "我们已向\(email)发送了验证邮件。\n请点击链接完成注册。") }
    static var backToSignIn: String { tr("로그인으로 돌아가기", "Back to Sign In", "ログインに戻る", "返回登录") }
    static var signInWithEmail: String { tr("이메일로 로그인", "Sign in with Email", "メールでログイン", "使用邮箱登录") }
    static var email: String { tr("이메일", "Email", "メール", "邮箱") }
    static var password: String { tr("비밀번호", "Password", "パスワード", "密码") }
    static var signIn: String { tr("로그인", "Sign In", "ログイン", "登录") }
    static var signUp: String { tr("회원가입", "Sign Up", "新規登録", "注册") }
    static var createAccount: String { tr("계정이 없으신가요? 회원가입", "Don't have an account? Sign Up", "アカウントをお持ちでない方はこちら", "没有账号？注册") }
    static var noAccount: String { tr("계정이 없으신가요?", "Don't have an account?", "アカウントをお持ちでない方", "没有账号？") }
    static var hasAccount: String { tr("이미 계정이 있으신가요?", "Already have an account?", "既にアカウントをお持ちの方", "已有账号？") }
    static var alreadyHaveAccount: String { tr("이미 계정이 있으신가요? 로그인", "Already have an account? Sign In", "既にアカウントをお持ちの方はこちら", "已有账号？登录") }
}
