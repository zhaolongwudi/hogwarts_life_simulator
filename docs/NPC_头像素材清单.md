# NPC 名单 · 头像素材需求清单

> 生成时间：2026-09-21
> 数据源：`lib/data/npc_data.dart`（现有 102 位种子 NPC）+ 原著常见遗漏项
> 用途：把这份清单交给图片模型/真人照提供者，产出后再回填到代码库

---

## 一、当前项目状态说明

### 1.1 数据结构现状
`NpcSeed` 类目前只有文字字段：`id / name / aliases / house / grade / bloodStatus / personality / appearance / era / gender / sexOrientation / giftPrefs / personalGoal`。**没有 avatar/imageUrl/portrait 等图片字段**——加入头像能力属于新增系统而非修 bug，本次不擅动。

后续接入时最小侵入方案：在 `NpcSeed` 里加一个 `String? portraitKey`（可选），指向 `assets/portraits/{portraitKey}.png` 或 `.webp`；运行时用 `Image.asset('assets/portraits/$key.png')` 加载，key 为空则回落到首字母头像占位符。

### 1.2 版权风险告知
电影剧照是 Warner Bros. Discovery 的版权资产，直接从公网抓取用于本项目的商业分发（哪怕只自用打包成 APK）都可能触发 DMCA take-down。安全做法有三条：
1. **AI 生成同风格但不完全一样的肖像**（推荐，最省心）
2. **官方授权素材**（几乎不可能拿到）
3. **同人插画社区找 CC-BY 授权作品**（可以但数量有限）

下面清单里给出每位 NPC 的**英文名 + 中文译名 + 关键外貌线索 + 建议来源**，你可以据此挑一条路径。

---

## 二、已在项目中的 102 位 NPC（按时代分组）

### A. 教职员工（所有时代通用）· staffSeeds

| id | 中文名 | 英文名 | 主要演员参考 |
|---|---|---|---|
| dumbledore | 阿不思·邓布利多 | Albus Dumbledore | Michael Gambon (GOB+) / Richard Harris (G&CS/CoS) |
| mcgonagall | 米勒娃·麦格 | Minerva McGonagall | Maggie Smith |
| snape | 西弗勒斯·斯内普 | Severus Snape | Alan Rickman |
| hagrid | 鲁伯·海格 | Rubeus Hagrid | Robbie Coltrane |
| lucius_malfoy | 卢修斯·马尔福 | Lucius Malfoy | Jason Isaacs |
| lily_evans | 莉莉·伊万斯 | Lily Evans | Geraldine James / Emma Thompson (闪回) |
| flitwick | 菲利乌斯·弗立维 | Filius Flitwick | David Bradley |
| sprout | 波莫娜·斯普劳特 | Pomona Sprout | Susan Heyward |
| trelawney | 西比尔·特里劳妮 | Sibyll Trelawney | Emma Thompson |
| quirrell | 奎里尔 | Quirinus Quirrell | Chris Reece (未纳入 NPC 表 — 见下) |
|Vector | 韦斯莱夫人 | Molly Weasley | Julie Walters |
| arthur_weasley | 亚瑟·韦斯莱 | Arthur Weasley | Mark Williams |
| filch | 阿格斯·费尔奇 | Argus Filch | David Bradley(?) |
| binns | 宾斯教授 | Professor Binns | Hugh Welchman |
| slughorn | 斯莱特林院长替代(食死徒时代)| Horace Slughorn (未录入) | Jim Broadbent |
| mulderbury | 罗兰达·霍琦 | Rowena Rosebery/Hooch | Kerry Hill |
| pince | 伊尔玛·平斯 | Irma Pince | Louise Bretherton |
| olivanders | 加里克·奥利凡德 | Garrick Ollivander | John Brown |
| bogartin | 穆尔塞伯 / Boggart | Boggart | David Thewlis |

### B. 哈里斯代（第一战结束～第四部）· harrySame*

- 格兰芬多：哈利·波特 Harry Potter、赫敏·格兰杰 Hermione Granger、罗恩·韦斯莱 Ron Weasley、纳威·隆巴顿 Neville Longbottom、金妮·韦斯莱 Ginny Weasley、秋·张 Cho Chang、迪安·托马斯 Dean Thomas
- 斯莱特林：德拉科·马尔福 Draco Malfoy、潘西·帕金森 Pansy Parkinson、文森特·克拉布 Vincent Crabbe、格雷戈里·高尔 Gregory Goyle、米利森特·巴沙特 Millicent Bulstrode、布莱斯·沙比尼 Blaise Zabini、特拉弗斯 Theodore Nott
- 拉文克劳：卢娜·洛夫古德 Luna Lovegood、西奥多·诺特(Theodore Nott)、塞德里克·迪戈里 Cedric Diggory、埃文·罗齐尔 Evan Rosier
- 赫奇帕奇：汉娜·艾博 Hannah Abbott、苏珊·波恩Susan Bones、扎卡赖斯·史密斯 Zacharias Smith、本吉·芬威克 Benjy Fenwick
- 其他学院成员：李·乔丹 Lee Jordan、埃德加·博恩斯 Edgarbone、安吉丽娜·约翰逊 Angelina Johnson、柯林·克里维 Colin Creevey、弗雷德·韦斯莱 Fred Weasley、乔治·韦斯莱 George Weasley、奥利弗·伍德 Oliver Wood、拉文德·布朗 Lavender Brown、西莫·斐尼甘 Seamus Finnigan、厄尼·麦克米兰 Ernie Macmillan、温妮弗雷德·奥利弗 Ginny Weasley (注：项目当前把"薇薇安"混进来了)

### C. Marauders 时代（第一部时期）· maraudersSeeds
詹姆斯·波特 James Sirius/Little James Potter、小天狼星·布莱克 Sirius Black、莱姆斯·卢平 Remus Lupin、小矮星彼得 Peter Pettigrew

### D. 邓布利多早期（第二、三部）· dumbledoreEraSeeds
盖勒特·格林德沃 Gellert Grindelwald、赛拉斯·斯洛克莫顿 Seraphide/Slytherin Elder? 待核、马琳·麦金农 Marlene McKinnon、贝拉特里克斯·布莱克 Bellatrix Lestrange、莱桑德拉·亚克斯利 Andromeda/Lesandra Tonks、佩尔佩图亚·范考特 Petunia Dursley、卡勒姆·福利 Callum Fowler、维多利亚·韦斯莱 Victoria Weasley、霍诺莉亚·佩弗利尔 Honororia Potter-Peverell、埃莉诺·万斯 Elinor Vance、埃米琳·万斯 Emlynne Vance、加拉多克·迪尔伯恩 Cadwallader Dilliburn?、卡拉多克·迪尔伯恩 Cadmus Dillyburn?、卡尔皮尔·博金斯 Callimere/Percival Boggy、费比安·普威特 Fabian Prewett、吉迪翁·普威特 Gideon Prewett、多卡斯·梅多斯 Dorcas Meadows、维克托娃·韦斯莱 Victoire Weasley、罗丝·韦斯莱 Rose Weasley、雨果·韦斯莱 Hugo Weasley、罗杰·戴维斯 Roger Davies、巴纳比·克鲁克 Barnaby Crookshanks?

### E. 战后时代（第七部以后）· postWarSeeds
詹姆·小天狼星·波特 James Sirius Potter、泰迪·卢平 Tedd Tonks Lupin、阿不思·西弗勒斯·波特 Albus Severus Potter、雷古勒斯·布莱克 Regulus Black、斯科皮·马尔福 Scorpius Malfoy、德尔菲·里德尔 Delphi Ridgeback/Delfada Rogue、普里娅·沙菲克 Priya Shafiq、洛娜·斯卡曼德 Lottie Scamander、珀西·韦斯莱 Percy Weasley、温妮弗雷德·奥利弗 Winky/Oliver Wood 之女、阿格斯·费尔奇 之子韦瑟比·费尔奇 Wesbite Filch?、阿芒多·迪佩特 Armando Dippet、罗斯默塔夫人 Rosa/Montrose?

### F. 第一次巫师战争原住民 · firstWarOriginals
伏地魔 Voldemort、盖勒特·格林德沃 Grindelwald、贝拉特里克斯·布莱克 Bellatrix、雷古勒斯·布莱克 Regulus、科尔文·冈特 Corvinus Gaunt、安布罗修·弗鲁姆 Amcaro/Mosad/Frudge 之一、加里·沃尔什?

（部分翻译名与原著不完全对应，以代码为准。）

---

## 三、识别到的原著重要遗漏项（建议补充候选，共 ~28 人）

### 3.1 核心教师 / 校方
- [ ] 奎里尔 Professor Quirrell（第一部反派宿敌，缺）
- [ ] 斯拉格霍恩 Horace Slughorn（第五~七部，重要导师角色）
- [ ] 弗伦奇教授 Madame Hooch (已录) / Madam Puddifoot 等 (选修课老师可少量补)
- [ ] 斯内普年轻时的学生: 佩内洛(已录)、汤姆·里德尔 Tom Riddle (少年伏地魔)
- [ ] 校长前任: Armando Dippet (已录), Phineas Nigellus Black, Imelda Morcant, Bathilda Bagshot

### 3.2 家庭与亲友团
- [ ] 德思礼一家 Vernon Dursley / Petunia Dursley (Petunia 已录)/ Dudley Dudley (Dudley 缺席)
- [ ] 韦斯莱家：罗恩的双胞胎哥哥们（弗雷德/乔治都已录）、摩莉(Molly)母系人物可能缺
- [ ] 珀西的前妻 潘妮·黛恩 Penny Deane (post-war 重要)

### 3.3 死亡圣器支线重要角色
- [ ] **石墩/邓布利多军之外的黑魔王阵营**: 
  - 纳西莎·马尔福 Narcissa Malfoy
  - 德拉科的朋友 Theo Nott 弟弟？（Theodore 已在斯莱特林列了？）

### 3.4 神奇动物相关
- [ ] 纽特·斯卡曼德 Newt Scamander (Lottie 已有；父辈缺)
- [ ] 忒瑞·布赖滕瓦尔德/魔法生物司同事若干
- [ ] 麻瓜保护委员会成员：道格拉斯 (Douglas) 之类

### 3.5 其他常见出场
- [ ] 阿格斯·费尔奇的老婆或子女（现只有韦瑟比子/女，不确定完整度）
- [ ] 丽塔·斯基特 Rita Skeeter (记者，快讯社同好已提到但 NPC 表可能缺)
- [ ] 卢娜之父 Xenophilius Lovegood《古怪故事》主编
- [ ] 霍拉斯·斯拉格霍恩、斯普劳特、霍奇之外还有一批选修课教授可轻量补齐

> ⚠️ 上表是"我觉得可能缺"的推测，实际核对请到 `npc_data.dart` 每个 seed list 里对号入座。**不要盲抄**。

---

## 四、头像素材交付格式建议

若你准备让图片模型生成，请约定如下规范：
- 尺寸：正方形 512×512（预留圆角裁切余量）
- 命名：`{npc_id}.png` 或 `{npc_id}.webp`（直接复用现有 id，例如 `dumbledore.png` / `snape.webp`）
- 目录：放到 `assets/portraits/` 下
- 风格一致性：**同一批次必须统一画风**（写实/漫画/Q版/水彩 选一种），避免 UI 里看起来像不同游戏拼贴
- 元数据：每张图右上角留出 4px 边距放学院色标（红/绿/蓝/黄）

## 五、下一步（等你的选择）

1. ✅ 我可以先扩写 NPC 池（补 §3 里的遗漏项，纯 Dart 数据，不影响 CI）。是否要我直接动手？
2. 🟡 我可以先把 `NpcSeed` 类扩展 `portraitKey` 字段 + 添加 assets 加载器骨架，然后你在应用里逐张替换占位图。这一步动了模型层，需要你确认。
3. 🔴 我不擅自从网络抓电影剧照放进仓库。如果你想走这条路，得走 AI 生成。