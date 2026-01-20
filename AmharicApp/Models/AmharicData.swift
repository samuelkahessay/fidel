import Foundation

struct AmharicData {
    
    static let fidelChart: [[FidelCharacter]] = {
        let consonants = [
            ("h", "ሀ", ["ha", "hu", "hi", "ha", "he", "h", "ho"]),
            ("l", "ለ", ["la", "lu", "li", "la", "le", "l", "lo"]),
            ("h", "ሐ", ["ha", "hu", "hi", "ha", "he", "h", "ho"]),
            ("m", "መ", ["ma", "mu", "mi", "ma", "me", "m", "mo"]),
            ("s", "ሠ", ["sa", "su", "si", "sa", "se", "s", "so"]),
            ("r", "ረ", ["ra", "ru", "ri", "ra", "re", "r", "ro"]),
            ("s", "ሰ", ["sa", "su", "si", "sa", "se", "s", "so"]),
            ("sh", "ሸ", ["sha", "shu", "shi", "sha", "she", "sh", "sho"]),
            ("q", "ቀ", ["qa", "qu", "qi", "qa", "qe", "q", "qo"]),
            ("b", "በ", ["ba", "bu", "bi", "ba", "be", "b", "bo"]),
            ("v", "ቨ", ["va", "vu", "vi", "va", "ve", "v", "vo"]),
            ("t", "ተ", ["ta", "tu", "ti", "ta", "te", "t", "to"]),
            ("ch", "ቸ", ["cha", "chu", "chi", "cha", "che", "ch", "cho"]),
            ("h", "ኀ", ["ha", "hu", "hi", "ha", "he", "h", "ho"]),
            ("n", "ነ", ["na", "nu", "ni", "na", "ne", "n", "no"]),
            ("ny", "ኘ", ["nya", "nyu", "nyi", "nya", "nye", "ny", "nyo"]),
            ("'", "አ", ["a", "u", "i", "a", "e", "'", "o"]),
            ("k", "ከ", ["ka", "ku", "ki", "ka", "ke", "k", "ko"]),
            ("kh", "ኸ", ["kha", "khu", "khi", "kha", "khe", "kh", "kho"]),
            ("w", "ወ", ["wa", "wu", "wi", "wa", "we", "w", "wo"]),
            ("'", "ዐ", ["a", "u", "i", "a", "e", "'", "o"]),
            ("z", "ዘ", ["za", "zu", "zi", "za", "ze", "z", "zo"]),
            ("zh", "ዠ", ["zha", "zhu", "zhi", "zha", "zhe", "zh", "zho"]),
            ("y", "የ", ["ya", "yu", "yi", "ya", "ye", "y", "yo"]),
            ("d", "ደ", ["da", "du", "di", "da", "de", "d", "do"]),
            ("j", "ጀ", ["ja", "ju", "ji", "ja", "je", "j", "jo"]),
            ("g", "ገ", ["ga", "gu", "gi", "ga", "ge", "g", "go"]),
            ("t'", "ጠ", ["t'a", "t'u", "t'i", "t'a", "t'e", "t'", "t'o"]),
            ("ch'", "ጨ", ["ch'a", "ch'u", "ch'i", "ch'a", "ch'e", "ch'", "ch'o"]),
            ("p'", "ጰ", ["p'a", "p'u", "p'i", "p'a", "p'e", "p'", "p'o"]),
            ("ts'", "ጸ", ["ts'a", "ts'u", "ts'i", "ts'a", "ts'e", "ts'", "ts'o"]),
            ("ts'", "ፀ", ["ts'a", "ts'u", "ts'i", "ts'a", "ts'e", "ts'", "ts'o"]),
            ("f", "ፈ", ["fa", "fu", "fi", "fa", "fe", "f", "fo"]),
            ("p", "ፐ", ["pa", "pu", "pi", "pa", "pe", "p", "po"]),
        ]
        
        let characters: [String] = [
            "ሀ", "ሁ", "ሂ", "ሃ", "ሄ", "ህ", "ሆ",
            "ለ", "ሉ", "ሊ", "ላ", "ሌ", "ል", "ሎ",
            "ሐ", "ሑ", "ሒ", "ሓ", "ሔ", "ሕ", "ሖ",
            "መ", "ሙ", "ሚ", "ማ", "ሜ", "ም", "ሞ",
            "ሠ", "ሡ", "ሢ", "ሣ", "ሤ", "ሥ", "ሦ",
            "ረ", "ሩ", "ሪ", "ራ", "ሬ", "ር", "ሮ",
            "ሰ", "ሱ", "ሲ", "ሳ", "ሴ", "ስ", "ሶ",
            "ሸ", "ሹ", "ሺ", "ሻ", "ሼ", "ሽ", "ሾ",
            "ቀ", "ቁ", "ቂ", "ቃ", "ቄ", "ቅ", "ቆ",
            "በ", "ቡ", "ቢ", "ባ", "ቤ", "ብ", "ቦ",
            "ቨ", "ቩ", "ቪ", "ቫ", "ቬ", "ቭ", "ቮ",
            "ተ", "ቱ", "ቲ", "ታ", "ቴ", "ት", "ቶ",
            "ቸ", "ቹ", "ቺ", "ቻ", "ቼ", "ች", "ቾ",
            "ኀ", "ኁ", "ኂ", "ኃ", "ኄ", "ኅ", "ኆ",
            "ነ", "ኑ", "ኒ", "ና", "ኔ", "ን", "ኖ",
            "ኘ", "ኙ", "ኚ", "ኛ", "ኜ", "ኝ", "ኞ",
            "አ", "ኡ", "ኢ", "ኣ", "ኤ", "እ", "ኦ",
            "ከ", "ኩ", "ኪ", "ካ", "ኬ", "ክ", "ኮ",
            "ኸ", "ኹ", "ኺ", "ኻ", "ኼ", "ኽ", "ኾ",
            "ወ", "ዉ", "ዊ", "ዋ", "ዌ", "ው", "ዎ",
            "ዐ", "ዑ", "ዒ", "ዓ", "ዔ", "ዕ", "ዖ",
            "ዘ", "ዙ", "ዚ", "ዛ", "ዜ", "ዝ", "ዞ",
            "ዠ", "ዡ", "ዢ", "ዣ", "ዤ", "ዥ", "ዦ",
            "የ", "ዩ", "ዪ", "ያ", "ዬ", "ይ", "ዮ",
            "ደ", "ዱ", "ዲ", "ዳ", "ዴ", "ድ", "ዶ",
            "ጀ", "ጁ", "ጂ", "ጃ", "ጄ", "ጅ", "ጆ",
            "ገ", "ጉ", "ጊ", "ጋ", "ጌ", "ግ", "ጎ",
            "ጠ", "ጡ", "ጢ", "ጣ", "ጤ", "ጥ", "ጦ",
            "ጨ", "ጩ", "ጪ", "ጫ", "ጬ", "ጭ", "ጮ",
            "ጰ", "ጱ", "ጲ", "ጳ", "ጴ", "ጵ", "ጶ",
            "ጸ", "ጹ", "ጺ", "ጻ", "ጼ", "ጽ", "ጾ",
            "ፀ", "ፁ", "ፂ", "ፃ", "ፄ", "ፅ", "ፆ",
            "ፈ", "ፉ", "ፊ", "ፋ", "ፌ", "ፍ", "ፎ",
            "ፐ", "ፑ", "ፒ", "ፓ", "ፔ", "ፕ", "ፖ",
        ]
        
        var result: [[FidelCharacter]] = []
        for (index, consonantInfo) in consonants.enumerated() {
            var row: [FidelCharacter] = []
            for vowelOrder in 0..<7 {
                let charIndex = index * 7 + vowelOrder
                if charIndex < characters.count {
                    row.append(FidelCharacter(
                        character: characters[charIndex],
                        consonant: consonantInfo.0,
                        vowelOrder: vowelOrder + 1,
                        romanization: consonantInfo.2[vowelOrder],
                        audioHint: consonantInfo.2[vowelOrder]
                    ))
                }
            }
            result.append(row)
        }
        return result
    }()
    
    static let patterns: [Pattern] = [
        Pattern(
            id: "1.1",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "I am + [adjective/state]",
            structure: "እኔ + [adjective] + ነኝ",
            template: "ine + [adjective] + nany",
            examples: [
                Pattern.Example(amharic: "እኔ ደህና ነኝ", transliteration: "ine dahna nany", english: "I am well/fine"),
                Pattern.Example(amharic: "እኔ ታማሚ ነኝ", transliteration: "ine tamami nany", english: "I am sick"),
                Pattern.Example(amharic: "እኔ ተማሪ ነኝ", transliteration: "ine tamari nany", english: "I am a student"),
                Pattern.Example(amharic: "እኔ ደክሞኛል ነኝ", transliteration: "ine dakmonynal nany", english: "I am tired")
            ],
            substitutions: [
                Pattern.Substitution(amharic: "ደህና", transliteration: "dahna", english: "well, fine"),
                Pattern.Substitution(amharic: "ታማሚ", transliteration: "tamami", english: "sick"),
                Pattern.Substitution(amharic: "ተማሪ", transliteration: "tamari", english: "student"),
                Pattern.Substitution(amharic: "ሠራተኛ", transliteration: "saratanya", english: "worker"),
                Pattern.Substitution(amharic: "ደስተኛ", transliteration: "dastanya", english: "happy")
            ]
        ),
        Pattern(
            id: "1.2",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "You are + [adjective] (masculine informal)",
            structure: "አንተ + [adjective] + ነህ",
            template: "anta + [adjective] + nah",
            examples: [
                Pattern.Example(amharic: "አንተ ደህና ነህ?", transliteration: "anta dahna nah?", english: "Are you well? (m)"),
                Pattern.Example(amharic: "አንተ ተማሪ ነህ", transliteration: "anta tamari nah", english: "You are a student")
            ],
            substitutions: []
        ),
        Pattern(
            id: "1.3",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "You are + [adjective] (feminine informal)",
            structure: "አንቺ + [adjective] + ነሽ",
            template: "anchi + [adjective] + nash",
            examples: [
                Pattern.Example(amharic: "አንቺ ደህና ነሽ?", transliteration: "anchi dahna nash?", english: "Are you well? (f)")
            ],
            substitutions: []
        ),
        Pattern(
            id: "1.4",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "He/She is + [adjective]",
            structure: "እሱ/እሷ + [adjective] + ነው/ነች",
            template: "issu/isswa + [adjective] + naw/nach",
            examples: [
                Pattern.Example(amharic: "እሱ ደህና ነው", transliteration: "issu dahna naw", english: "He is well"),
                Pattern.Example(amharic: "እሷ ደህና ነች", transliteration: "isswa dahna nach", english: "She is well")
            ],
            substitutions: []
        ),
        Pattern(
            id: "1.5",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "We are + [adjective]",
            structure: "እኛ + [adjective] + ነን",
            template: "inya + [adjective] + nan",
            examples: [
                Pattern.Example(amharic: "እኛ ደህና ነን", transliteration: "inya dahna nan", english: "We are well"),
                Pattern.Example(amharic: "እኛ ሁለታችንም ደህና ነን", transliteration: "inya hulattachinim dahna nan", english: "We both are well")
            ],
            substitutions: []
        ),
        Pattern(
            id: "1.6",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "They are + [adjective]",
            structure: "እነሱ + [adjective] + ናቸው",
            template: "inassu + [adjective] + nachaw",
            examples: [
                Pattern.Example(amharic: "እነሱ ደህና ናቸው", transliteration: "inassu dahna nachaw", english: "They are well"),
                Pattern.Example(amharic: "አባትና እናት ደህና ናቸው", transliteration: "abbat inna innat dahna nachaw", english: "Father and mother are well")
            ],
            substitutions: []
        ),
        Pattern(
            id: "1.7",
            category: "BASIC PRESENT TENSE (Subject + Verb)",
            unit: 1,
            description: "You are + [adjective] (formal/polite)",
            structure: "እርስዎ + [adjective] + ነዎት",
            template: "irswo + [adjective] + nawot",
            examples: [
                Pattern.Example(amharic: "እርስዎ ደህና ነዎት?", transliteration: "irswo dahna nawot?", english: "Are you well? (formal)")
            ],
            substitutions: []
        ),
        Pattern(
            id: "2.1",
            category: "POSSESSIVE PHRASES",
            unit: 2,
            description: "My + [noun]",
            structure: "የኔ + [noun]",
            template: "yane + [noun]",
            examples: [
                Pattern.Example(amharic: "የኔ ሚስት", transliteration: "yane mist", english: "my wife"),
                Pattern.Example(amharic: "የኔ አባት", transliteration: "yane abbat", english: "my father"),
                Pattern.Example(amharic: "የኔ እናት", transliteration: "yane innat", english: "my mother"),
                Pattern.Example(amharic: "የኔ መጽሐፍ", transliteration: "yane mashaf", english: "my book"),
                Pattern.Example(amharic: "የኔ ልጅ", transliteration: "yane lij", english: "my child")
            ],
            substitutions: [
                Pattern.Substitution(amharic: "ሚስት", transliteration: "mist", english: "wife"),
                Pattern.Substitution(amharic: "አባት", transliteration: "abbat", english: "father"),
                Pattern.Substitution(amharic: "እናት", transliteration: "innat", english: "mother"),
                Pattern.Substitution(amharic: "ልጅ", transliteration: "lij", english: "child"),
                Pattern.Substitution(amharic: "መጽሐፍ", transliteration: "mashaf", english: "book"),
                Pattern.Substitution(amharic: "ቤት", transliteration: "bet", english: "house"),
                Pattern.Substitution(amharic: "ስም", transliteration: "sim", english: "name")
            ]
        ),
        Pattern(
            id: "2.2",
            category: "POSSESSIVE PHRASES",
            unit: 2,
            description: "Your + [noun] (formal)",
            structure: "የርስዎ + [noun]",
            template: "yarswo + [noun]",
            examples: [
                Pattern.Example(amharic: "የርስዎ ሚስት", transliteration: "yarswo mist", english: "your wife (formal)"),
                Pattern.Example(amharic: "የርስዎ አባት", transliteration: "yarswo abbat", english: "your father")
            ],
            substitutions: []
        ),
        Pattern(
            id: "3.1",
            category: "BASIC QUESTIONS",
            unit: 3,
            description: "How are you?",
            structure: "እንደምን + [verb form]",
            template: "indamin + [verb form]",
            examples: [
                Pattern.Example(amharic: "እንደምን ነህ?", transliteration: "indamin nah?", english: "How are you? (m)"),
                Pattern.Example(amharic: "እንደምን ነሽ?", transliteration: "indamin nash?", english: "How are you? (f)"),
                Pattern.Example(amharic: "እንደምን ነዎት?", transliteration: "indamin nawot?", english: "How are you? (formal)")
            ],
            substitutions: []
        ),
        Pattern(
            id: "4.1",
            category: "BASIC RESPONSES",
            unit: 4,
            description: "Yes, I am [adjective]",
            structure: "አዎ፣ + [statement]",
            template: "awo, + [statement]",
            examples: [
                Pattern.Example(amharic: "አዎ፣ ደህና ነኝ", transliteration: "awo, dahna nany", english: "Yes, I am well"),
                Pattern.Example(amharic: "አዎ፣ ደህና ናቸው", transliteration: "awo, dahna nachaw", english: "Yes, they are well")
            ],
            substitutions: []
        ),
        Pattern(
            id: "5.1",
            category: "COMMON EXPRESSIONS",
            unit: 5,
            description: "I want + [noun]",
            structure: "[noun] + እፈልጋለሁ",
            template: "[noun] + ifaligalahu",
            examples: [
                Pattern.Example(amharic: "ቡና እፈልጋለሁ", transliteration: "buna ifaligalahu", english: "I want coffee"),
                Pattern.Example(amharic: "ውሃ እፈልጋለሁ", transliteration: "wuha ifaligalahu", english: "I want water"),
                Pattern.Example(amharic: "ሻይ እፈልጋለሁ", transliteration: "shay ifaligalahu", english: "I want tea")
            ],
            substitutions: [
                Pattern.Substitution(amharic: "ቡና", transliteration: "buna", english: "coffee"),
                Pattern.Substitution(amharic: "ውሃ", transliteration: "wuha", english: "water"),
                Pattern.Substitution(amharic: "ሻይ", transliteration: "shay", english: "tea"),
                Pattern.Substitution(amharic: "ምግብ", transliteration: "migib", english: "food")
            ]
        ),
        Pattern(
            id: "5.2",
            category: "COMMON EXPRESSIONS",
            unit: 5,
            description: "Where is [place]?",
            structure: "[place] + የት ነው?",
            template: "[place] + yat naw?",
            examples: [
                Pattern.Example(amharic: "ሆቴል የት ነው?", transliteration: "hotel yat naw?", english: "Where is the hotel?"),
                Pattern.Example(amharic: "ቦሌ የት ነው?", transliteration: "Bole yat naw?", english: "Where is Bole?"),
                Pattern.Example(amharic: "ሆስፒታል የት ነው?", transliteration: "hospital yat naw?", english: "Where is the hospital?")
            ],
            substitutions: []
        ),
        Pattern(
            id: "5.3",
            category: "COMMON EXPRESSIONS",
            unit: 5,
            description: "How much is it?",
            structure: "ምን ያህል ነው?",
            template: "min yahil naw?",
            examples: [
                Pattern.Example(amharic: "ይህ ምን ያህል ነው?", transliteration: "yih min yahil naw?", english: "How much is this?"),
                Pattern.Example(amharic: "ሃያ ብር ነው", transliteration: "haya birr naw", english: "It's 20 birr")
            ],
            substitutions: []
        )
    ]
    
    static let conversations: [Conversation] = [
        Conversation(
            id: 1,
            title: "INFORMAL GREETING (Meeting a Friend)",
            difficulty: 1,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "ጤና ይስጥልኝ ሂሩት። እንደምን ነሽ? ደህና ነሽ?", transliteration: "t'ena yist'illiany Hirut. indamin nash? dahna nash?", english: "Hello, Hirut. How are you? Are you well?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "ጤና ይስጥልኝ ከበደ። አዎ፣ ደህና ነኝ። አንተስ እንደምን ነህ?", transliteration: "t'ena yist'illiany Kabada. awo, dahna nany. antass indamin nah?", english: "Hello, Kebbede. Yes, I'm well. And you, how are you?"),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "እኔም ደህና ነኝ። እግዚአብሔር ይመስገን።", transliteration: "inemm dahna nany. igziabher yimmesgan.", english: "I'm fine too, thank you."),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "ሃይሉ ደህና ነው?", transliteration: "Haylu dahna naw?", english: "Is Haylu well?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "አዎ፣ እሱም ደህና ነው።", transliteration: "awo, issumm dahna naw.", english: "Yes, he's fine too."),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "አባትና እናትህ ደህና ናቸው?", transliteration: "abbat-inna innatih dahna nachaw?", english: "Are your father and mother well?"),
                Conversation.DialogueLine(lineNum: 7, speaker: "PERSON A", amharic: "አዎ፣ ደህና ናቸው።", transliteration: "awo, dahna nachaw.", english: "Yes, they're well."),
                Conversation.DialogueLine(lineNum: 8, speaker: "PERSON B", amharic: "በል አሁን መሄድ አለብኝ። ደህና ሁን።", transliteration: "bal ahun mahed allabiny. dahna hun.", english: "Well, I have to go now. Goodbye."),
                Conversation.DialogueLine(lineNum: 9, speaker: "PERSON A", amharic: "ደህና ሁኝ ሂሩት።", transliteration: "dahna hunyi, Hirut.", english: "Goodbye, Hirut.")
            ]
        ),
        Conversation(
            id: 2,
            title: "FORMAL GREETING (Meeting an Acquaintance)",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "MRS. HIYWET", amharic: "ጤና ይስጥልኝ አቶ ሙሉጌታ። እንደምን አደሩ? ደህና ነዎት?", transliteration: "t'ena yist'illiany Ato Mulugeta. indamin addaru? dahna nawot?", english: "Hello, Mr. Mulugeta. Good morning. Are you well?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "MR. MULUGETA", amharic: "ደህና ነኝ፣ ወይዘሮ ሕይወት። እግዚአብሔር ይመስገን። እርስዎስ እንደምን ነዎት?", transliteration: "dahna nany, Wayzaro Hiywat. igziabher yimmesgan. irswoss indamin nawot?", english: "I am well, Mrs. Hiywet, thank you. And you, how are you?"),
                Conversation.DialogueLine(lineNum: 3, speaker: "MRS. HIYWET", amharic: "አዎ፣ ደህና ነኝ። የርስዎ ሚስት እንደምን ናቸው?", transliteration: "awo, dahna nany. yarswo mist indamin nachaw?", english: "Yes, I am well. How is your wife?"),
                Conversation.DialogueLine(lineNum: 4, speaker: "MR. MULUGETA", amharic: "የኔ ሚስት ደህና ነች። እግዚአብሔር ይመስገን። እኛ ሁለታችንም ደህና ነን።", transliteration: "yane mist dahna nach. igziabher yimmesgan. inya hulattachinim dahna nan.", english: "My wife is well, thank you. We are both well."),
                Conversation.DialogueLine(lineNum: 5, speaker: "MRS. HIYWET", amharic: "እሺ፣ ደህና ይዋሉ።", transliteration: "ishi, dahna yiwalu.", english: "OK, goodbye."),
                Conversation.DialogueLine(lineNum: 6, speaker: "MR. MULUGETA", amharic: "ደህና ይዋሉ።", transliteration: "dahna yiwalu.", english: "Goodbye.")
            ]
        ),
        Conversation(
            id: 3,
            title: "ORDERING COFFEE (At a Cafe)",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "CUSTOMER", amharic: "ጤና ይስጥልኝ።", transliteration: "t'ena yist'illiany.", english: "Hello."),
                Conversation.DialogueLine(lineNum: 2, speaker: "WAITER", amharic: "ጤና ይስጥልህ። እንኳን ደህና መጣህ።", transliteration: "t'ena yist'illih. inkuan dahna mattah.", english: "Hello. Welcome."),
                Conversation.DialogueLine(lineNum: 3, speaker: "CUSTOMER", amharic: "አንድ ቡና እፈልጋለሁ።", transliteration: "and buna ifaligalahu.", english: "I want one coffee."),
                Conversation.DialogueLine(lineNum: 4, speaker: "WAITER", amharic: "ከስኳር ይሆን?", transliteration: "ka-sukuar yihon?", english: "With sugar?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "CUSTOMER", amharic: "አዎ፣ ከስኳር። አመሰግናለሁ።", transliteration: "awo, ka-sukuar. ameseginalehu.", english: "Yes, with sugar. Thank you."),
                Conversation.DialogueLine(lineNum: 6, speaker: "WAITER", amharic: "በጣም ደህና። አሁን አምጣለሁ።", transliteration: "batam dahna. ahun amtalehu.", english: "Very good. I'll bring it now."),
                Conversation.DialogueLine(lineNum: 7, speaker: "CUSTOMER", amharic: "ጣፋጭ ነው። ሂሳቡን አምጣልኝ።", transliteration: "tafach naw. hisabun amtaliny.", english: "It's delicious. Bring me the bill."),
                Conversation.DialogueLine(lineNum: 8, speaker: "WAITER", amharic: "እሺ። ሃያ ብር ነው።", transliteration: "ishi. haya birr naw.", english: "OK. It's 20 birr."),
                Conversation.DialogueLine(lineNum: 9, speaker: "CUSTOMER", amharic: "እነሆ። አመሰግናለሁ።", transliteration: "inaho. ameseginalehu.", english: "Here you are. Thank you."),
                Conversation.DialogueLine(lineNum: 10, speaker: "WAITER", amharic: "ደህና ይሁኑ።", transliteration: "dahna yihunu.", english: "Goodbye.")
            ]
        ),
        Conversation(
            id: 4,
            title: "ASKING FOR DIRECTIONS",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "ይቅርታ፣ እንደምን ነዎት?", transliteration: "yikirta, indamin nawot?", english: "Excuse me, how are you?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "ደህና ነኝ። እርስዎስ?", transliteration: "dahna nany. irswoss?", english: "I'm well. And you?"),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "ደህና። ቦሌ የት ነው?", transliteration: "dahna. Bole yat naw?", english: "Fine. Where is Bole?"),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "ቦሌ እዚህ ከፊት ነው። ቀጥታ ይሂዱ።", transliteration: "Bole izzih kafit naw. qattita yihidu.", english: "Bole is straight ahead. Go straight."),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "ምን ያህል ርቀት ነው?", transliteration: "min yahil riket naw?", english: "How far is it?"),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "አንድ ኪሎ ሜትር ያህል። በእግር ከአስር ደቂቃ።", transliteration: "and kilo meter yahil. ba-igir ka-asir dakika.", english: "About one kilometer. About ten minutes on foot."),
                Conversation.DialogueLine(lineNum: 7, speaker: "PERSON A", amharic: "በጣም አመሰግናለሁ።", transliteration: "batam ameseginalehu.", english: "Thank you very much."),
                Conversation.DialogueLine(lineNum: 8, speaker: "PERSON B", amharic: "ምንም አይደለም። ደህና ይሁኑ።", transliteration: "minim aydallam. dahna yihunu.", english: "You're welcome. Goodbye.")
            ]
        ),
        Conversation(
            id: 5,
            title: "INTRODUCING YOURSELF",
            difficulty: 1,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "ጤና ይስጥልኝ። ስሜ ዳዊት ነው። የእርስዎስ ስም ማነው?", transliteration: "t'ena yist'illiany. sime Dawit naw. ya-irswoss sim man naw?", english: "Hello. My name is Dawit. What's your name?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "ስሜ ሳራ ነው። ደስ ብሎኛል።", transliteration: "sime Sara naw. das bilonyal.", english: "My name is Sara. Nice to meet you."),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "እኔም ደስ ብሎኛል። ከየት ነሽ?", transliteration: "inemm das bilonyal. kayat nash?", english: "Nice to meet you too. Where are you from?"),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "እኔ ከአሜሪካ ነኝ። አንተስ ከየት ነህ?", transliteration: "ine ka-Amerika nany. antass kayat nah?", english: "I'm from America. And you, where are you from?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "እኔ ከኢትዮጵያ ነኝ። ከአዲስ አበባ ነኝ።", transliteration: "ine ka-Ityoppya nany. ka-Addis Ababa nany.", english: "I'm from Ethiopia. I'm from Addis Ababa."),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "በጣም ጥሩ። አማርኛ ትችያለሽ?", transliteration: "batam tiru. amaranya tichiyalash?", english: "Very good. Do you speak Amharic?"),
                Conversation.DialogueLine(lineNum: 7, speaker: "PERSON A", amharic: "አዎ፣ ትንሽ። አንቺስ አማርኛ ትማሪያለሽ?", transliteration: "awo, tinish. anchiss amaranya timariyalash?", english: "Yes, a little. Are you learning Amharic?"),
                Conversation.DialogueLine(lineNum: 8, speaker: "PERSON B", amharic: "አዎ፣ ተማሪ ነኝ። አሁን አማርኛ እማራለሁ።", transliteration: "awo, tamari nany. ahun amaranya imaralahu.", english: "Yes, I'm a student. I'm learning Amharic now.")
            ]
        ),
        Conversation(
            id: 6,
            title: "SHOPPING AT THE MARKET",
            difficulty: 3,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "CUSTOMER", amharic: "ጤና ይስጥልኝ። ይህ ምን ያህል ነው?", transliteration: "t'ena yist'illiany. yih min yahil naw?", english: "Hello. How much is this?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "SELLER", amharic: "ጤና ይስጥልህ። አምሳ ብር ነው።", transliteration: "t'ena yist'illih. amsa birr naw.", english: "Hello. It's fifty birr."),
                Conversation.DialogueLine(lineNum: 3, speaker: "CUSTOMER", amharic: "ውድ ነው። ሃያ ብር እሰጣለሁ።", transliteration: "wid naw. haya birr isatalahu.", english: "It's expensive. I'll give you twenty birr."),
                Conversation.DialogueLine(lineNum: 4, speaker: "SELLER", amharic: "አይ፣ በጣም ትንሽ ነው። አርባ ብር።", transliteration: "ay, batam tinish naw. arba birr.", english: "No, that's too little. Forty birr."),
                Conversation.DialogueLine(lineNum: 5, speaker: "CUSTOMER", amharic: "እሺ፣ ሰላሳ ብር።", transliteration: "ishi, salasa birr.", english: "OK, thirty birr."),
                Conversation.DialogueLine(lineNum: 6, speaker: "SELLER", amharic: "እሺ፣ ሰላሳ ብር። ትክክል ነው።", transliteration: "ishi, salasa birr. tikil naw.", english: "OK, thirty birr. That's fair."),
                Conversation.DialogueLine(lineNum: 7, speaker: "CUSTOMER", amharic: "እነሆ። አመሰግናለሁ።", transliteration: "inaho. ameseginalehu.", english: "Here you are. Thank you."),
                Conversation.DialogueLine(lineNum: 8, speaker: "SELLER", amharic: "አመሰግናለሁ። ደህና ይሁኑ።", transliteration: "ameseginalehu. dahna yihunu.", english: "Thank you. Goodbye.")
            ]
        ),
        Conversation(
            id: 7,
            title: "TALKING ABOUT FAMILY",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "የቤተሰብህ ስንት ናቸው?", transliteration: "ya-betesabih sint nachaw?", english: "How many are in your family?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "አባት፣ እናት፣ ሁለት እህቶች እና አንድ ወንድም።", transliteration: "abbat, innat, hulat ihitoch inna and wandim.", english: "Father, mother, two sisters, and one brother."),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "ጥሩ። ትልቅ ቤተሰብ ነው። የአባትህ ስም ማነው?", transliteration: "tiru. tilik betasab naw. ya-abbatih sim man naw?", english: "Good. It's a big family. What's your father's name?"),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "የአባቴ ስም ተስፋዬ ነው። የእናቴ ስም አልማዝ ነው።", transliteration: "ya-abbate sim Tasfaye naw. ya-innate sim Almaz naw.", english: "My father's name is Tesfaye. My mother's name is Almaz."),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "የእህቶችህስ ስሞች ምንድናቸው?", transliteration: "ya-ihitochihss simoch mindnachaw?", english: "What are your sisters' names?"),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "ሳራ እና ሄለን። የወንድሜ ስም ዳዊት ነው።", transliteration: "Sara inna Helen. ya-wandime sim Dawit naw.", english: "Sara and Helen. My brother's name is Dawit."),
                Conversation.DialogueLine(lineNum: 7, speaker: "PERSON A", amharic: "ቆንጆ ስሞች ናቸው።", transliteration: "konjo simoch nachaw.", english: "They're beautiful names.")
            ]
        ),
        Conversation(
            id: 8,
            title: "MAKING PLANS",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "ነገ ምን ታደርጋለህ?", transliteration: "naga min tadargalah?", english: "What are you doing tomorrow?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "ወደ ገበያ እሄዳለሁ። አንተስ?", transliteration: "wada gabaya ihedalahu. antass?", english: "I'm going to the market. And you?"),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "እኔም ነፃ ነኝ። በአንድነት እንሄድ።", transliteration: "inemm natsa nany. ba-andinnat inhid.", english: "I'm also free. Let's go together."),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "ጥሩ ሀሳብ ነው። መቼ እንገናኝ?", transliteration: "tiru hasab naw. macha inganany?", english: "Good idea. When shall we meet?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "በአስር ሰዓት። በቦሌ እንገናኝ።", transliteration: "ba-asir saat. ba-Bole inganany.", english: "At ten o'clock. Let's meet at Bole."),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "እሺ። ነገ እንገናኛለን።", transliteration: "ishi. naga ingananyalan.", english: "OK. We'll see each other tomorrow.")
            ]
        ),
        Conversation(
            id: 9,
            title: "PHONE CONVERSATION",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "አሎ? ከሃይሉ ጋር መናገር እችላለሁ?", transliteration: "alo? ka-Haylu gar managar ichilalahu?", english: "Hello? Can I speak with Haylu?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "አዎ፣ እሱ ነው። ማነው?", transliteration: "awo, issu naw. man naw?", english: "Yes, this is he. Who is this?"),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "እኔ ከበደ ነኝ። እንደምን ነህ?", transliteration: "ine Kabada nany. indamin nah?", english: "It's Kebbede. How are you?"),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "ደህና ነኝ፣ አመሰግናለሁ። አንተስ?", transliteration: "dahna nany, ameseginalehu. antass?", english: "I'm well, thank you. And you?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "ደህና። ነገ ነፃ ነህ?", transliteration: "dahna. naga natsa nah?", english: "Fine. Are you free tomorrow?"),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "አዎ፣ ነፃ ነኝ። ለምን?", transliteration: "awo, natsa nany. lamin?", english: "Yes, I'm free. Why?"),
                Conversation.DialogueLine(lineNum: 7, speaker: "PERSON A", amharic: "እንገናኝ። ቡና እንጠጣ።", transliteration: "inganany. buna intat'at'a.", english: "Let's meet. Let's have coffee."),
                Conversation.DialogueLine(lineNum: 8, speaker: "PERSON B", amharic: "ጥሩ ሀሳብ ነው። በስንት ሰዓት?", transliteration: "tiru hasab naw. ba-sint saat?", english: "Good idea. At what time?"),
                Conversation.DialogueLine(lineNum: 9, speaker: "PERSON A", amharic: "በአራት ሰዓት። በፒያሳ።", transliteration: "ba-arat saat. ba-Piyasa.", english: "At four o'clock. At Piazza."),
                Conversation.DialogueLine(lineNum: 10, speaker: "PERSON B", amharic: "እሺ። ነገ እንገናኛለን።", transliteration: "ishi. naga ingananyalan.", english: "OK. We'll see each other tomorrow.")
            ]
        ),
        Conversation(
            id: 10,
            title: "SMALL TALK (Weather & Daily Life)",
            difficulty: 2,
            lines: [
                Conversation.DialogueLine(lineNum: 1, speaker: "PERSON A", amharic: "የአየር ሁኔታው እንዴት ነው?", transliteration: "ya-ayar hunetaw indet naw?", english: "How's the weather?"),
                Conversation.DialogueLine(lineNum: 2, speaker: "PERSON B", amharic: "ዛሬ ቆንጆ ነው። ፀሐይ አለ።", transliteration: "zare konjo naw. tsahay alla.", english: "Today it's nice. It's sunny."),
                Conversation.DialogueLine(lineNum: 3, speaker: "PERSON A", amharic: "ትናንት ዝናብ ነበረ።", transliteration: "tinant zinab nabara.", english: "Yesterday it rained."),
                Conversation.DialogueLine(lineNum: 4, speaker: "PERSON B", amharic: "አዎ፣ ብዙ ዝናብ ነበረ። አሁን ምን እየሰራህ ነው?", transliteration: "awo, bizu zinab nabara. ahun min iyasarah naw?", english: "Yes, it rained a lot. What are you doing now?"),
                Conversation.DialogueLine(lineNum: 5, speaker: "PERSON A", amharic: "መጽሐፍ እያነበብኩ ነው። አንተስ?", transliteration: "mashaf iyanababku naw. antass?", english: "I'm reading a book. And you?"),
                Conversation.DialogueLine(lineNum: 6, speaker: "PERSON B", amharic: "እኔ ቡና እጠጣለሁ።", transliteration: "ine buna itat'alahu.", english: "I'm drinking coffee.")
            ]
        )
    ]
    
    static let phrases: [Phrase] = [
        Phrase(id: 1, amharic: "ጤና ይስጥልኝ", transliteration: "t'ena yist'illiany", english: "Hello", notes: "Universal greeting"),
        Phrase(id: 2, amharic: "እንደምን ነህ?", transliteration: "indamin nah?", english: "How are you?", notes: "Masc. informal"),
        Phrase(id: 3, amharic: "እንደምን ነሽ?", transliteration: "indamin nash?", english: "How are you?", notes: "Fem. informal"),
        Phrase(id: 4, amharic: "እንደምን ነዎት?", transliteration: "indamin nawot?", english: "How are you?", notes: "Formal"),
        Phrase(id: 5, amharic: "ደህና ነኝ", transliteration: "dahna nany", english: "I'm fine", notes: "Standard response"),
        Phrase(id: 6, amharic: "እንደምን አደሩ?", transliteration: "indamin addaru?", english: "Good morning", notes: "Formal"),
        Phrase(id: 7, amharic: "እንደምን ዋሉ?", transliteration: "indamin walu?", english: "Good evening", notes: "Formal"),
        Phrase(id: 8, amharic: "ደህና ሁን", transliteration: "dahna hun", english: "Goodbye", notes: "Masc. informal"),
        Phrase(id: 9, amharic: "ደህና ሁኝ", transliteration: "dahna hunyi", english: "Goodbye", notes: "Fem. informal"),
        Phrase(id: 10, amharic: "ደህና ይዋሉ", transliteration: "dahna yiwalu", english: "Goodbye", notes: "Formal"),
        Phrase(id: 11, amharic: "እግዚአብሔር ይመስገን", transliteration: "igziabher yimmesgan", english: "Thank God", notes: "Standard thank you"),
        Phrase(id: 12, amharic: "አመሰግናለሁ", transliteration: "ameseginalehu", english: "Thank you", notes: "Direct thank you"),
        Phrase(id: 13, amharic: "ምንም አይደለም", transliteration: "minim aydallam", english: "You're welcome", notes: "It's nothing"),
        Phrase(id: 14, amharic: "ይቅርታ", transliteration: "yikirta", english: "Excuse me / Sorry", notes: "Multi-purpose"),
        Phrase(id: 15, amharic: "አዝናለሁ", transliteration: "aznalehu", english: "I'm sorry", notes: "Sympathy"),
        Phrase(id: 16, amharic: "ስምህ ማነው?", transliteration: "simih mannaw?", english: "What's your name?", notes: "Masc. informal"),
        Phrase(id: 17, amharic: "ስሜ [name] ነው", transliteration: "sime [name] naw", english: "My name is [name]", notes: "Introduction"),
        Phrase(id: 18, amharic: "ከየት ነህ?", transliteration: "kayat nah?", english: "Where are you from?", notes: "Masc. informal"),
        Phrase(id: 19, amharic: "ከ[country] ነኝ", transliteration: "ka-[country] nany", english: "I'm from [country]", notes: "Origin"),
        Phrase(id: 20, amharic: "የት ነው?", transliteration: "yat naw?", english: "Where is it?", notes: "Essential question"),
        Phrase(id: 21, amharic: "ይህ ምን ነው?", transliteration: "yih min naw?", english: "What is this?", notes: "Identifying objects"),
        Phrase(id: 22, amharic: "ምን ያህል ነው?", transliteration: "min yahil naw?", english: "How much is it?", notes: "Shopping"),
        Phrase(id: 23, amharic: "መቼ ነው?", transliteration: "macha naw?", english: "When is it?", notes: "Time questions"),
        Phrase(id: 24, amharic: "ለምን?", transliteration: "lamin?", english: "Why?", notes: "Question word"),
        Phrase(id: 25, amharic: "እንዴት?", transliteration: "indet?", english: "How?", notes: "Question word"),
        Phrase(id: 26, amharic: "አዎ", transliteration: "awo", english: "Yes", notes: "Affirmative"),
        Phrase(id: 27, amharic: "አይ", transliteration: "ay", english: "No", notes: "Negative"),
        Phrase(id: 28, amharic: "እሺ", transliteration: "ishi", english: "OK / Alright", notes: "Agreement"),
        Phrase(id: 29, amharic: "ትክክል", transliteration: "tikil", english: "Correct / Right", notes: "Confirmation"),
        Phrase(id: 30, amharic: "አልገባኝም", transliteration: "algabanyim", english: "I don't understand", notes: "Essential!"),
        Phrase(id: 31, amharic: "እፈልጋለሁ", transliteration: "ifaligalahu", english: "I want", notes: "Add object before"),
        Phrase(id: 32, amharic: "ቡና እፈልጋለሁ", transliteration: "buna ifaligalahu", english: "I want coffee", notes: "Common request"),
        Phrase(id: 33, amharic: "ውሃ እፈልጋለሁ", transliteration: "wuha ifaligalahu", english: "I want water", notes: "Common request"),
        Phrase(id: 34, amharic: "መሄድ አለብኝ", transliteration: "mahed allabiny", english: "I have to go", notes: "Obligation"),
        Phrase(id: 35, amharic: "እችላለሁ", transliteration: "ichilalahu", english: "I can", notes: "Ability"),
        Phrase(id: 36, amharic: "ተማሪ ነኝ", transliteration: "tamari nany", english: "I'm a student", notes: "Profession"),
        Phrase(id: 37, amharic: "አማርኛ እማራለሁ", transliteration: "amaranya imaralahu", english: "I'm learning Amharic", notes: "Useful!"),
        Phrase(id: 38, amharic: "ትንሽ", transliteration: "tinish", english: "A little", notes: "Modifier"),
        Phrase(id: 39, amharic: "በጣም", transliteration: "batam", english: "Very / Too", notes: "Emphasis"),
        Phrase(id: 40, amharic: "ደስ ብሎኛል", transliteration: "das bilonyal", english: "Nice to meet you", notes: "Greeting"),
        Phrase(id: 41, amharic: "ጥሩ ሀሳብ ነው", transliteration: "tiru hasab naw", english: "Good idea", notes: "Agreement"),
        Phrase(id: 42, amharic: "እንገናኝ", transliteration: "inganany", english: "Let's meet", notes: "Making plans"),
        Phrase(id: 43, amharic: "ነገ", transliteration: "naga", english: "Tomorrow", notes: "Time word"),
        Phrase(id: 44, amharic: "ዛሬ", transliteration: "zare", english: "Today", notes: "Time word"),
        Phrase(id: 45, amharic: "አሁን", transliteration: "ahun", english: "Now", notes: "Time word"),
        Phrase(id: 46, amharic: "እርዳታ!", transliteration: "irdata!", english: "Help!", notes: "Emergency"),
        Phrase(id: 47, amharic: "ዶክተር ፈልጋለሁ", transliteration: "doktar faligalahu", english: "I need a doctor", notes: "Medical"),
        Phrase(id: 48, amharic: "ፖሊስ ጥሪ", transliteration: "polis tiri", english: "Call the police", notes: "Emergency"),
        Phrase(id: 49, amharic: "ሆስፒታል የት ነው?", transliteration: "hospital yat naw?", english: "Where is the hospital?", notes: "Medical"),
        Phrase(id: 50, amharic: "አማርኛ አልችልም", transliteration: "amaranya alichilim", english: "I don't speak Amharic", notes: "Useful!")
    ]
    
    static let numbers: [(amharic: String, transliteration: String, value: Int)] = [
        ("አንድ", "and", 1),
        ("ሁለት", "hulat", 2),
        ("ሦስት", "sost", 3),
        ("አራት", "arat", 4),
        ("አምስት", "amist", 5),
        ("ስድስት", "sidist", 6),
        ("ሰባት", "sabat", 7),
        ("ስምንት", "simint", 8),
        ("ዘጠኝ", "zatany", 9),
        ("አስር", "asir", 10),
        ("ሃያ", "haya", 20),
        ("ሰላሳ", "salasa", 30),
        ("አርባ", "arba", 40),
        ("አምሳ", "amsa", 50),
        ("ስልሳ", "silsa", 60),
        ("ሰባ", "saba", 70),
        ("ሰማኒያ", "samaniya", 80),
        ("ዘጠና", "zatana", 90),
        ("መቶ", "mato", 100)
    ]
    
    static let vocabulary: [VocabularyWord] = [
        VocabularyWord(category: "Family", amharic: "አባት", transliteration: "abbat", english: "father"),
        VocabularyWord(category: "Family", amharic: "እናት", transliteration: "innat", english: "mother"),
        VocabularyWord(category: "Family", amharic: "ወንድም", transliteration: "wandim", english: "brother"),
        VocabularyWord(category: "Family", amharic: "እህት", transliteration: "ihit", english: "sister"),
        VocabularyWord(category: "Family", amharic: "ልጅ", transliteration: "lij", english: "child"),
        VocabularyWord(category: "Family", amharic: "ሚስት", transliteration: "mist", english: "wife"),
        VocabularyWord(category: "Family", amharic: "ባል", transliteration: "bal", english: "husband"),
        VocabularyWord(category: "Family", amharic: "ቤተሰብ", transliteration: "betasab", english: "family"),
        VocabularyWord(category: "Family", amharic: "አያት", transliteration: "ayat", english: "grandparent"),
        VocabularyWord(category: "Food & Drink", amharic: "ቡና", transliteration: "buna", english: "coffee"),
        VocabularyWord(category: "Food & Drink", amharic: "ሻይ", transliteration: "shay", english: "tea"),
        VocabularyWord(category: "Food & Drink", amharic: "ውሃ", transliteration: "wuha", english: "water"),
        VocabularyWord(category: "Food & Drink", amharic: "ወተት", transliteration: "watat", english: "milk"),
        VocabularyWord(category: "Food & Drink", amharic: "ዳቦ", transliteration: "dabo", english: "bread"),
        VocabularyWord(category: "Food & Drink", amharic: "እንጀራ", transliteration: "injara", english: "injera"),
        VocabularyWord(category: "Food & Drink", amharic: "ምግብ", transliteration: "migib", english: "food"),
        VocabularyWord(category: "Food & Drink", amharic: "ስኳር", transliteration: "sukuar", english: "sugar"),
        VocabularyWord(category: "Food & Drink", amharic: "ጨው", transliteration: "chaw", english: "salt"),
        VocabularyWord(category: "Places", amharic: "ቤት", transliteration: "bet", english: "house"),
        VocabularyWord(category: "Places", amharic: "ሆቴል", transliteration: "hotel", english: "hotel"),
        VocabularyWord(category: "Places", amharic: "ገበያ", transliteration: "gabaya", english: "market"),
        VocabularyWord(category: "Places", amharic: "ሱቅ", transliteration: "suk", english: "shop"),
        VocabularyWord(category: "Places", amharic: "ሆስፒታል", transliteration: "hospital", english: "hospital"),
        VocabularyWord(category: "Places", amharic: "ትምህርት ቤት", transliteration: "timhirt bet", english: "school"),
        VocabularyWord(category: "Places", amharic: "ቤተ ክርስቲያን", transliteration: "beta kristiyan", english: "church"),
        VocabularyWord(category: "Places", amharic: "መስጊድ", transliteration: "masgid", english: "mosque"),
        VocabularyWord(category: "Body Parts", amharic: "ጭንቅላት", transliteration: "chinkilat", english: "head"),
        VocabularyWord(category: "Body Parts", amharic: "አይን", transliteration: "ayn", english: "eye"),
        VocabularyWord(category: "Body Parts", amharic: "አፍ", transliteration: "af", english: "mouth"),
        VocabularyWord(category: "Body Parts", amharic: "እጅ", transliteration: "ij", english: "hand"),
        VocabularyWord(category: "Body Parts", amharic: "እግር", transliteration: "igir", english: "foot/leg"),
        VocabularyWord(category: "Body Parts", amharic: "ጆሮ", transliteration: "joro", english: "ear"),
        VocabularyWord(category: "Colors", amharic: "ቀይ", transliteration: "kay", english: "red"),
        VocabularyWord(category: "Colors", amharic: "አረንጓዴ", transliteration: "aranguade", english: "green"),
        VocabularyWord(category: "Colors", amharic: "ሰማያዊ", transliteration: "samayawi", english: "blue"),
        VocabularyWord(category: "Colors", amharic: "ቢጫ", transliteration: "bicha", english: "yellow"),
        VocabularyWord(category: "Colors", amharic: "ጥቁር", transliteration: "tikur", english: "black"),
        VocabularyWord(category: "Colors", amharic: "ነጭ", transliteration: "nach", english: "white"),
        VocabularyWord(category: "Time", amharic: "ዛሬ", transliteration: "zare", english: "today"),
        VocabularyWord(category: "Time", amharic: "ነገ", transliteration: "naga", english: "tomorrow"),
        VocabularyWord(category: "Time", amharic: "ትናንት", transliteration: "tinant", english: "yesterday"),
        VocabularyWord(category: "Time", amharic: "አሁን", transliteration: "ahun", english: "now"),
        VocabularyWord(category: "Time", amharic: "ሰዓት", transliteration: "saat", english: "hour/time"),
        VocabularyWord(category: "Time", amharic: "ቀን", transliteration: "kan", english: "day"),
        VocabularyWord(category: "Time", amharic: "ሳምንት", transliteration: "samint", english: "week"),
        VocabularyWord(category: "Time", amharic: "ወር", transliteration: "war", english: "month"),
        VocabularyWord(category: "Directions", amharic: "ቀኝ", transliteration: "kany", english: "right"),
        VocabularyWord(category: "Directions", amharic: "ግራ", transliteration: "gira", english: "left"),
        VocabularyWord(category: "Directions", amharic: "ቀጥታ", transliteration: "kattita", english: "straight"),
        VocabularyWord(category: "Directions", amharic: "ከላይ", transliteration: "kalay", english: "up/above"),
        VocabularyWord(category: "Directions", amharic: "ከታች", transliteration: "katach", english: "down/below"),
        VocabularyWord(category: "Directions", amharic: "እዚህ", transliteration: "izzih", english: "here"),
        VocabularyWord(category: "Directions", amharic: "እዚያ", transliteration: "izziya", english: "there"),
        VocabularyWord(category: "Common Adjectives", amharic: "ደህና", transliteration: "dahna", english: "well/fine"),
        VocabularyWord(category: "Common Adjectives", amharic: "ጥሩ", transliteration: "tiru", english: "good"),
        VocabularyWord(category: "Common Adjectives", amharic: "መጥፎ", transliteration: "matfo", english: "bad"),
        VocabularyWord(category: "Common Adjectives", amharic: "ትልቅ", transliteration: "tilik", english: "big"),
        VocabularyWord(category: "Common Adjectives", amharic: "ትንሽ", transliteration: "tinish", english: "small/little"),
        VocabularyWord(category: "Common Adjectives", amharic: "ቆንጆ", transliteration: "konjo", english: "beautiful/nice"),
        VocabularyWord(category: "Common Adjectives", amharic: "ውድ", transliteration: "wid", english: "expensive"),
        VocabularyWord(category: "Common Adjectives", amharic: "ርካሽ", transliteration: "rikash", english: "cheap"),
        VocabularyWord(category: "Days", amharic: "ሰኞ", transliteration: "sanyo", english: "Monday"),
        VocabularyWord(category: "Days", amharic: "ማክሰኞ", transliteration: "maksanyo", english: "Tuesday"),
        VocabularyWord(category: "Days", amharic: "ረቡዕ", transliteration: "rabu", english: "Wednesday"),
        VocabularyWord(category: "Days", amharic: "ሐሙስ", transliteration: "hamus", english: "Thursday"),
        VocabularyWord(category: "Days", amharic: "አርብ", transliteration: "arb", english: "Friday"),
        VocabularyWord(category: "Days", amharic: "ቅዳሜ", transliteration: "kidame", english: "Saturday"),
        VocabularyWord(category: "Days", amharic: "እሁድ", transliteration: "ihud", english: "Sunday")
    ]
    
    static var vocabularyCategories: [String] {
        Array(Set(vocabulary.map { $0.category })).sorted()
    }
    
    static func vocabularyByCategory(_ category: String) -> [VocabularyWord] {
        vocabulary.filter { $0.category == category }
    }
    
    static let lessons: [Lesson] = [
        Lesson(
            id: 1,
            title: "Greetings & Introductions",
            description: "Learn basic greetings and how to introduce yourself",
            patterns: patterns.filter { $0.unit == 1 },
            vocabulary: vocabulary.filter { ["Family", "Common Adjectives"].contains($0.category) },
            phrases: Array(phrases.prefix(15))
        ),
        Lesson(
            id: 2,
            title: "Possessives & Family",
            description: "Talk about your family and possessions",
            patterns: patterns.filter { $0.unit == 2 },
            vocabulary: vocabulary.filter { $0.category == "Family" },
            phrases: phrases.filter { $0.id >= 16 && $0.id <= 25 }
        ),
        Lesson(
            id: 3,
            title: "Questions & Directions",
            description: "Ask questions and find your way around",
            patterns: patterns.filter { $0.unit == 3 },
            vocabulary: vocabulary.filter { ["Directions", "Places"].contains($0.category) },
            phrases: phrases.filter { $0.id >= 20 && $0.id <= 30 }
        ),
        Lesson(
            id: 4,
            title: "Food & Shopping",
            description: "Order food, shop at markets, and handle money",
            patterns: patterns.filter { $0.unit == 4 || $0.unit == 5 },
            vocabulary: vocabulary.filter { $0.category == "Food & Drink" },
            phrases: phrases.filter { $0.id >= 31 && $0.id <= 40 }
        ),
        Lesson(
            id: 5,
            title: "Making Plans & Time",
            description: "Talk about time, make plans, and schedule activities",
            patterns: patterns.filter { $0.unit == 5 },
            vocabulary: vocabulary.filter { ["Time", "Days"].contains($0.category) },
            phrases: phrases.filter { $0.id >= 41 && $0.id <= 50 }
        )
    ]
}
