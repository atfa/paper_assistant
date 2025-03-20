import 'package:flutter/material.dart';
import 'text_splitter.dart';

class TextSplitterDemo extends StatefulWidget {
  const TextSplitterDemo({Key? key}) : super(key: key);

  @override
  State<TextSplitterDemo> createState() => _TextSplitterDemoState();
}

class _TextSplitterDemoState extends State<TextSplitterDemo> {
  final TextEditingController _textController = TextEditingController();
  List<String> _splitResult = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _splitText() {
    setState(() {
      _splitResult = TextSplitter.smartSplit(_textController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文本切分演示'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '输入要切分的文本...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _splitText,
              child: const Text('切分文本'),
            ),
            const SizedBox(height: 16),
            const Text(
              '切分结果:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _splitResult.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${index + 1}. ${_splitResult[index]}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 使用示例
void main() {
  runApp(const MaterialApp(
    home: TextSplitterDemo(),
  ));
}

// 示例文本:
// 
// 中文示例:
// "我很喜欢这本书。它的故事情节非常吸引人。作者的文笔很棒！你读过吗？我强烈推荐你也读一读。"
//
// 英文示例:
// "The U.S.A. is a large country. Mr. Smith is the C.E.O. of that company. He earned his Ph.D. from Harvard. This is a complex problem. We need to solve it carefully."