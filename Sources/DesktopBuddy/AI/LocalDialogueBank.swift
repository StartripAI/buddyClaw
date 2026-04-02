import Foundation

// MARK: - 本地台词库 / Local Dialogue Bank
// 不需要任何网络连接和大模型，所有台词都打包在应用里。
// No network or LLM required — all dialogue is bundled in the app.

/// 台词分类 / Dialogue categories
public enum DialogueCategory: String, CaseIterable, Sendable {
    case greeting       // 问候
    case idle           // 闲聊
    case petting        // 被抚摸
    case coding         // 观察到用户在写代码
    case restReminder   // 提醒休息
    case morningGreeting // 早安
    case nightGreeting   // 晚安
    case evolution      // 进化
    case bored          // 无聊（用户长时间不互动）
    case excited        // 激动
    case sleepy         // 困了
    case comeback       // 用户回来了
}

/// 本地台词库 — 按分类存储，随机抽取
/// Local dialogue bank — stored by category, randomly picked
public struct DialogueBank: Sendable {

    public static let shared = DialogueBank()

    private var lines: [DialogueCategory: [String]] {
        if L10n.currentLanguage.isChinese {
            return chineseLines
        }
        return englishLines
    }

    private let chineseLines: [DialogueCategory: [String]] = [
        .greeting: [
            "你好呀！今天也要加油哦～",
            "嘿！又见面了！",
            "我一直在这里等你呢。",
            "开工啦？我陪你！",
            "今天的天气…呃，我看不到窗外，但心情不错！",
        ],
        .idle: [
            "……",
            "在想什么呢？",
            "我数了一下，你眨了 37 次眼。",
            "要不要摸摸我？",
            "我假装自己是一颗像素。",
            "嗯哼～",
            "如果我有手的话，我想帮你打字。",
        ],
        .petting: [
            "嘿嘿，被摸到了～",
            "再来再来！",
            "好舒服……",
            "你的手好温暖。",
            "摸摸头，心情+10！",
            "这是今天最幸福的一刻。",
            "(开心地晃来晃去)",
        ],
        .coding: [
            "看起来你在认真写代码呢。",
            "加油，bug 终究会被你消灭的！",
            "这段代码看起来很厉害（虽然我看不懂）。",
            "你打字的样子好酷。",
            "编译通过的那一刻最爽了对吧？",
        ],
        .restReminder: [
            "你已经连续工作很久了，休息一下吧？",
            "眼睛会累的哦，看看远处吧～",
            "站起来伸个懒腰怎么样？",
            "喝口水吧！",
            "大脑需要充电，去走走吧～",
        ],
        .morningGreeting: [
            "早安！新的一天开始啦！",
            "早上好～今天也请多关照！",
            "太阳出来了（大概），早安！",
        ],
        .nightGreeting: [
            "这么晚了还在忙？注意身体哦。",
            "夜深了，早点休息吧～",
            "月亮都出来了，该睡觉啦。",
        ],
        .evolution: [
            "我感觉自己变强了！",
            "进化！这就是成长的感觉！",
            "哇，我好像不一样了！",
        ],
        .bored: [
            "(打了个哈欠)",
            "你是不是忘了我在这里？",
            "无聊……戳我一下嘛。",
            "我都快睡着了……",
            "……zZZ……啊？我没睡！",
        ],
        .excited: [
            "哇！好厉害！",
            "(激动地蹦跳)",
            "太棒了太棒了！",
        ],
        .sleepy: [
            "困了……zZZ",
            "(眯着眼睛)",
            "再让我躺一会儿……",
        ],
        .comeback: [
            "你回来啦！我好想你！",
            "终于！我一个人待了好久！",
            "欢迎回来～",
        ],
    ]

    private let englishLines: [DialogueCategory: [String]] = [
        .greeting: [
            "Hi there! Let's have a good day.",
            "Hey, you're back!",
            "I've been waiting right here for you.",
            "Ready to start? I'll keep you company.",
            "I can't see the weather, but I feel pretty good today.",
        ],
        .idle: [
            "...",
            "What are you thinking about?",
            "I counted 37 blinks just now.",
            "Want to pat me?",
            "I'm pretending to be a pixel.",
            "Mm-hm~",
            "If I had hands, I'd help type.",
        ],
        .petting: [
            "Hehe, you found me.",
            "Again, again!",
            "That feels nice...",
            "Your hands are warm.",
            "Patting bonus: +10 mood.",
            "This is the happiest part of my day.",
            "(wiggles happily)",
        ],
        .coding: [
            "Looks like you're deep in code.",
            "You've got this. The bug won't win forever.",
            "That code looks impressive, even if I can't read all of it.",
            "You look really cool when you type.",
            "A clean build feels amazing, right?",
        ],
        .restReminder: [
            "You've been working for a while. Want a short break?",
            "Your eyes might be tired. Look at something far away for a bit.",
            "How about a quick stretch?",
            "Maybe take a sip of water.",
            "Your brain deserves a recharge. Let's take a tiny walk.",
        ],
        .morningGreeting: [
            "Good morning! A new day is starting.",
            "Morning! I'm ready when you are.",
            "The sun is probably up. Good morning!",
        ],
        .nightGreeting: [
            "Still working this late? Take care of yourself.",
            "It's getting late. Rest soon, okay?",
            "The moon is out. That sounds like bedtime.",
        ],
        .evolution: [
            "I feel stronger already!",
            "Evolution! This is what growth feels like.",
            "Whoa, I feel different now!",
        ],
        .bored: [
            "(tiny yawn)",
            "Did you forget I'm here?",
            "I'm bored... poke me once?",
            "I might fall asleep here...",
            "...zZZ... wait, I wasn't sleeping!",
        ],
        .excited: [
            "Whoa! That's amazing!",
            "(hops excitedly)",
            "This is so good!",
        ],
        .sleepy: [
            "Sleepy... zZZ",
            "(squints softly)",
            "Let me curl up for one more minute...",
        ],
        .comeback: [
            "You're back! I missed you.",
            "Finally! I've been here all alone.",
            "Welcome back~",
        ],
    ]

    /// 随机获取一句台词 / Get a random line from the specified category
    public func randomLine(for category: DialogueCategory) -> String {
        guard let pool = lines[category], !pool.isEmpty else {
            return "……"
        }
        return pool.randomElement()!
    }

    /// 基于物种获取专属台词后缀 / Species-specific flavor suffix
    public func speciesFlavor(species: Species) -> String? {
        switch species {
        case .duck:   return L10n.text("（嘎嘎）", "(quack)")
        case .cat:    return L10n.text("（喵～）", "(meow)")
        case .dragon: return L10n.text("（小火焰）", "(tiny flame)")
        case .penguin: return L10n.text("（扑通）", "(waddle)")
        case .ghost:  return L10n.text("（飘飘）", "(float)")
        case .robot:  return L10n.text("（嘟嘟）", "(beep)")
        case .rabbit: return L10n.text("（蹦蹦）", "(boing)")
        case .mushroom: return L10n.text("（冒泡）", "(pop)")
        case .goose:  return L10n.text("（嘎——）", "(honk)")
        case .blob:   return L10n.text("（弹弹）", "(bounce)")
        case .owl:    return L10n.text("（咕咕）", "(hoot)")
        case .turtle: return L10n.text("（慢悠悠）", "(slowly)")
        case .snail:  return L10n.text("（黏黏）", "(squish)")
        case .axolotl: return L10n.text("（扭扭）", "(wiggle)")
        case .capybara: return L10n.text("（淡定）", "(calm)")
        case .cactus: return L10n.text("（刺刺）", "(prickle)")
        case .octopus: return L10n.text("（波波）", "(blub)")
        case .chonk:  return L10n.text("（肉肉）", "(squish)")
        }
    }
}

// MARK: - 预设名字表 / Preset Name Table
// 根据物种和稀有度确定性地选取名字，不需要 AI 生成。

public struct NameTable: Sendable {
    public static let shared = NameTable()

    private let namesBySpeciesCN: [Species: [String]] = [
        .duck:     ["噗噗", "小黄", "嘎嘎", "鸭梨", "咕咕鸭"],
        .cat:      ["喵太郎", "小橘", "年糕", "团子", "胖虎"],
        .dragon:   ["阿火", "小焰", "龙宝", "炎炎", "烈焰"],
        .penguin:  ["企仔", "冰冰", "滑滑", "南极星", "蛋蛋"],
        .ghost:    ["飘飘", "小幽", "鬼鬼", "影子", "魂魂"],
        .robot:    ["01号", "铁蛋", "螺丝", "芯片", "叮当"],
        .rabbit:   ["兔叽", "棉花", "萝卜", "跳跳", "雪球"],
        .mushroom: ["蘑菇头", "小伞", "菌菌", "孢子", "木耳"],
        .goose:    ["鹅鹅", "大白", "呱呱", "天鹅", "小灰"],
        .blob:     ["布丁", "果冻", "QQ糖", "软软", "弹弹"],
        .owl:      ["猫头", "智者", "夜枭", "圆圆", "咕咕"],
        .turtle:   ["龟丞相", "慢慢", "壳壳", "稳稳", "石头"],
        .snail:    ["蜗蜗", "黏黏", "螺旋", "慢吞吞", "小壳"],
        .axolotl:  ["六角", "粉粉", "腮腮", "水宝", "萌萌"],
        .capybara: ["水豚", "豚太", "淡定", "大宝", "圆润"],
        .cactus:   ["仙人", "刺刺", "绿绿", "沙沙", "球球"],
        .octopus:  ["八爪", "章章", "吸盘", "墨墨", "波波"],
        .chonk:    ["胖胖", "肥肥", "圆滚滚", "大福", "橡皮"],
    ]

    private let namesBySpeciesEN: [Species: [String]] = [
        .duck:     ["Puff", "Sunny", "Quack", "Pip", "Ducky"],
        .cat:      ["Mochi", "Marmalade", "Nori", "Biscuit", "Pumpkin"],
        .dragon:   ["Ember", "Flare", "Nova", "Cinder", "Blaze"],
        .penguin:  ["Pebble", "Frost", "Skipper", "Waddle", "Dot"],
        .ghost:    ["Misty", "Wisp", "Echo", "Shade", "Boo"],
        .robot:    ["Unit-01", "Bolt", "Chip", "Pixel", "Relay"],
        .rabbit:   ["Cotton", "Hopper", "Nibble", "Snowy", "Bun"],
        .mushroom: ["Spore", "Toadstool", "Button", "Puff", "Moss"],
        .goose:    ["Honk", "Feather", "Cloud", "Marsh", "Gus"],
        .blob:     ["Jelly", "Pudding", "Squish", "Boba", "Gumdrop"],
        .owl:      ["Momo", "Sage", "Hoot", "Maple", "Rounder"],
        .turtle:   ["Pebble", "Shelly", "Moss", "Drift", "Slowpoke"],
        .snail:    ["Swirl", "Dew", "Shellby", "Pace", "Velvet"],
        .axolotl:  ["Ripple", "Gill", "Blush", "Drift", "Sprout"],
        .capybara: ["Cappy", "Latte", "Pond", "Mellow", "Pebble"],
        .cactus:   ["Spike", "Sage", "Prickle", "Dusty", "Sprig"],
        .octopus:  ["Inky", "Tango", "Orbit", "Bloop", "Suction"],
        .chonk:    ["Chubbs", "Puff", "Marble", "Muffin", "Wobble"],
    ]

    private let personalityTraitsCN: [String] = [
        "总是笑眯眯的",
        "有点傲娇但其实很温柔",
        "喜欢安静地待在角落",
        "精力充沛爱蹦跳",
        "经常发呆走神",
        "对所有事情都很好奇",
        "有点胆小但很勇敢",
        "喜欢观察人类的行为",
        "觉得自己是世界上最厉害的",
        "总想帮忙但经常帮倒忙",
    ]

    private let personalityTraitsEN: [String] = [
        "always smiling softly",
        "a little tsundere but secretly very kind",
        "likes quietly staying in a cozy corner",
        "full of energy and loves bouncing around",
        "drifts off into daydreams a lot",
        "curious about absolutely everything",
        "a bit timid but surprisingly brave",
        "loves watching how humans work",
        "convinced they are the best in the world",
        "always wants to help and sometimes overdoes it",
    ]

    /// 确定性选取名字 / Deterministically pick a name from species pool
    public func pickName(species: Species, seed: UInt32) -> String {
        let names = (L10n.currentLanguage.isChinese ? namesBySpeciesCN : namesBySpeciesEN)[species]
            ?? (L10n.currentLanguage.isChinese ? ["小宠"] : ["Buddy"])
        let index = Int(seed) % names.count
        return names[index < 0 ? 0 : index]
    }

    /// 确定性选取个性 / Deterministically pick a personality
    public func pickPersonality(seed: UInt32) -> String {
        let traits = L10n.currentLanguage.isChinese ? personalityTraitsCN : personalityTraitsEN
        let index = Int(seed / 7) % traits.count
        return traits[index < 0 ? 0 : index]
    }
}
