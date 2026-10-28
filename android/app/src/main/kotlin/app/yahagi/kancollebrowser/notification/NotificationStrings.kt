package app.yahagi.kancollebrowser.notification

/** Uses the app locale persisted with the snapshot, including background work. */
internal class NotificationStrings(private val localeCode: String = "zh") {
    private fun text(zh: String, hant: String, ja: String, ko: String, en: String): String = when (localeCode) {
        "ja" -> ja
        "ko" -> ko
        "en" -> en
        "zh_Hant" -> hant
        else -> zh
    }

    val channelNames: Map<String, String> get() = mapOf(
        "expedition" to text("远征通知", "遠征通知", "遠征通知", "원정 알림", "Expedition alerts"),
        "repair" to text("入渠修复", "入渠修復", "入渠修理", "입거 수리", "Dock repairs"),
        "anchorage" to text("泊地修理", "泊地修理", "泊地修理", "정박지 수리", "Anchorage repair"),
        "construction" to text("工厂建造", "工廠建造", "工廠建造", "공창 건조", "Ship construction"),
        "morale" to text("士气与刷闪", "士氣與刷閃", "士気・キラ付け", "사기 및 반짝이", "Morale and training"),
        "newShip" to text("新舰提醒", "新艦提醒", "未所持艦の通知", "미보유 함선 알림", "New ship alerts"),
    )
    val ongoingChannelName get() = text("母港实时进行中概览", "母港即時進行中概覽", "母港の進行状況", "모항 진행 상황", "Live port progress")
    val completed get() = text("已完成", "已完成", "完了", "완료", "Complete")
    val fallbackTitle get() = text("矢矧通知", "矢矧通知", "矢矧の通知", "矢矧 알림", "矢矧 notification")
    val retentionTitle get() = text("矢矧正在后台运行", "矢矧正在背景執行", "矢矧はバックグラウンドで動作中", "矢矧가 백그라운드에서 실행 중입니다", "矢矧 is running in the background")
    val retentionBody get() = text("游戏会话保持中 · 点击返回游戏", "遊戲工作階段保持中 · 點擊返回遊戲", "ゲームセッションを維持中 · タップしてゲームに戻る", "게임 세션 유지 중 · 눌러서 게임으로 돌아가기", "Keeping the game session active · Tap to return to the game")

    fun preemptBody(alarm: NotificationAlarm, remainingSeconds: Long): String {
        val seconds = remainingSeconds.coerceAtLeast(1L)
        val secondsText = "$seconds ${if (seconds == 1L) "second" else "seconds"}"
        alarm.bodyTemplate?.takeIf { it.isNotEmpty() }?.let {
            return Regex("\\{\\{|\\}\\}|\\{secondsText\\}|\\{seconds\\}").replace(it) { token ->
                when (token.value) {
                    "{{" -> "{"
                    "}}" -> "}"
                    "{secondsText}" -> secondsText
                    else -> seconds.toString()
                }
            }
        }
        // Legacy text can contain numbers in ship/fleet names. Render a fresh
        // countdown instead of trying to edit arbitrary captured prose.
        return text(
            "还有${seconds}秒", "還有${seconds}秒", "あと${seconds}秒", "${seconds}초 남음", "Ready in $secondsText",
        )
    }
    fun channelVariant(name: String, sound: Boolean, vibration: Boolean): String =
        "$name · ${if (sound) text("有声", "有聲", "音あり", "소리 켜짐", "Sound on") else text("静音", "靜音", "消音", "무음", "Silent")} · " +
            if (vibration) text("振动", "震動", "振動あり", "진동 켜짐", "Vibration on") else text("无振动", "無震動", "振動なし", "진동 꺼짐", "Vibration off")

    fun ongoingTitle(count: Int) = text(
        "矢矧 · 母港实时进行中 ($count 项)",
        "矢矧 · 母港即時進行中（$count 項）",
        "矢矧 · 母港の進行状況（${count}件）",
        "矢矧 · 모항 진행 상황 (${count}건)",
        "矢矧 · Port progress ($count ${if (count == 1) "task" else "tasks"})",
    )
    fun overflow(count: Int) = text(
        "另有 $count 项进行中或已完成任务",
        "另有 $count 項進行中或已完成任務",
        "ほかに進行中・完了済みのタスクが${count}件",
        "그 외 진행 중이거나 완료된 작업 ${count}건",
        "$count more active or completed ${if (count == 1) "task" else "tasks"}",
    )
}
