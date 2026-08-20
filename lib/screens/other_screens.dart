import 'package:flutter/material.dart';

class CommunicationScreen extends StatelessWidget {
  const CommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('魔法通讯')),
      body: ListView(
        children: [
          _buildContactTile('罗恩·韦斯莱', '正在吃鸡腿，没空想你', Icons.person, Colors.orange),
          _buildContactTile('赫敏·格兰杰', '图书馆见，有个课题要讨论', Icons.menu_book, Colors.brown),
          _buildContactTile('哈利·波特', '嘿，你听说那个传闻了吗？', Icons.star, Colors.blue),
          _buildContactTile('德拉科·马尔福', '（冷哼）有什么事？', Icons.school, Colors.grey),
          _buildContactTile('阿不思·邓布利多', '来我办公室一趟', Icons.wb_sunny, Colors.deepPurple),
          _buildContactTile('米勒娃·麦格教授', '变形术作业别忘了交', Icons.cast, Colors.amber),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildContactTile(String name, String message, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('魔法论坛')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildForumHeader(),
          const SizedBox(height: 12),
          _buildPostCard('校园八卦', '你们听说了吗？海德薇最近看起来很疲惫...', '3小时前', 128),
          _buildPostCard('学术讨论', '关于黑魔法防御术的教学改革', '1天前', 56),
          _buildPostCard('魁地奇', '格兰芬多 vs 斯莱特林前瞻分析', '2天前', 89),
          _buildPostCard('食谱分享', '霍格莫德村最好的热可可配方', '3天前', 42),
        ],
      ),
    );
  }

  Widget _buildForumHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('搜索帖子...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(String category, String content, String time, int likes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category, style: const TextStyle(fontSize: 12, color: Colors.blue)),
              ),
              const Spacer(),
              Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$likes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 16),
              const Icon(Icons.comment, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('回复', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _entries = [
    {
      'date': '1991年9月1日',
      'title': '入学第一天',
      'content': '今天终于来到了霍格沃茨！城堡在阳光下闪闪发光。在大礼堂吃了丰盛的早餐，然后开始了第一堂课。认识了几个新朋友，感觉这一年会很有趣。',
      'mood': '😊',
    },
    {
      'date': '1991年9月3日',
      'title': '第一场魔咒课',
      'content': '弗立维教授教了我们第一个咒语——"飞来咒"。罗恩把魔杖挥得太大，差点打到天花板。赫敏一次就成功了，不愧是学霸。',
      'mood': '😄',
    },
    {
      'date': '1991年9月15日',
      'title': '禁区探险',
      'content': '好奇驱使我们去了禁区边缘，结果被管理员费尔奇发现！我们跑了整整三圈才甩掉他。这次真的是太刺激了，也太蠢了...',
      'mood': '😰',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('查看日记')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(entry['mood']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry['date']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(entry['title']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(entry['content']!, style: const TextStyle(fontSize: 14, height: 1.6)),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
    );
  }
}
