import 'dart:io';
import 'package:hao_chatgpt/src/extensions.dart';
import 'package:hao_chatgpt/src/my_colors.dart';
import 'package:hao_chatgpt/src/network/entity/dio_error_entity.dart';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:hao_chatgpt/src/preferences_manager.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../l10n/generated/l10n.dart';
import '../network/entity/openai/completions_entity.dart';
import '../network/entity/openai/completions_query_entity.dart';
import '../network/openai_service.dart';

import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final Logger logger = Logger();
  final ScrollController _listController = ScrollController();
  final TextEditingController _msgController = TextEditingController();
  final _gpt3FocusNode = FocusNode();
  bool _isRequesting = false;
  final List<ListItem> _data = [];
  String _inputMessage = '';

  Future<void> _sendPrompt(PromptItem promptItem) async {
    CompletionsQueryEntity queryEntity =
        appPref.gpt3GenerationSettings ?? CompletionsQueryEntity.generation();
    logger.i(queryEntity.toJson());
    queryEntity.prompt = promptItem.appendedPrompt;
    try {
      CompletionsEntity entity =
          await openaiService.getCompletions(queryEntity);
      logger.i(entity.toJson());
      if (entity.choices != null && entity.choices!.isNotEmpty) {
        _data.add(CompletionItem(
          promptItem: promptItem,
          text: entity.choices!.first.text!,
        ));
      }
    } on DioError catch (e) {
      _data.add(ErrorItem(e.toEioErrorEntity));
    } on Exception catch (e) {
      _data.add(ErrorItem(e.toEioErrorEntity));
    } finally {
      if (mounted) {
        setState(() {
          _inputMessage = _msgController.text;
          _isRequesting = false;
        });
        _scrollToEnd();
      }
    }
  }

  String _appendPrompt() {
    var item = _data.lastWhere(
      (element) => element is CompletionItem || element is PromptItem,
      orElse: () => ErrorItem(DioErrorEntity()),
    );
    String newPrompt = '';
    if (item is CompletionItem) {
      newPrompt = '${item.promptItem.appendedPrompt}${item.text}\n\n';
    } else if (item is PromptItem) {
      newPrompt = item.appendedPrompt;
    }
    return '$newPrompt$_inputMessage\n\n';
  }

  bool _isEnabledSendButton() {
    return _inputMessage.isNotBlank && !_isRequesting;
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 50), () {
      _listController.animateTo(
        _listController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.bounceInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).chatGPT),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            onPressed: () {
              FocusScope.of(context).requestFocus(_gpt3FocusNode);
              context.push('/settings/gpt3');
            },
            icon: const Icon(Icons.dashboard_customize),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 1,
              color: Theme.of(context).primaryColorLight,
            ),
            Expanded(
              child: ListView.builder(
                controller: _listController,
                itemCount: (_data.isNotEmpty && _data.last is PromptItem)
                    ? _data.length + 1
                    : _data.length,
                itemBuilder: (context, index) {
                  if (index >= _data.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LoadingAnimationWidget.flickr(
                        leftDotColor: const Color(0xFF2196F3),
                        rightDotColor: const Color(0xFFF44336),
                        size: 24,
                      ),
                    );
                  } else {
                    if (_data[index] is PromptItem) {
                      return _buildPromptItem(context, index);
                    } else if (_data[index] is CompletionItem) {
                      return _buildCompletionItem(context, index);
                    } else {
                      return _buildErrorItem(context, index);
                    }
                  }
                },
              ),
            ),
            Container(
              height: 1,
              color: Theme.of(context).primaryColorLight,
            ),
            _buildPromptInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptItem(BuildContext context, int index) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_circle),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: SelectableText(
              (_data[index] as PromptItem).inputMessage,
              selectionControls:
                  Platform.isIOS ? myCupertinoTextSelectionControls : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionItem(BuildContext context, int index) {
    final myColors = Theme.of(context).extension<MyColors>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: myColors?.completionBackgroundColor,
      child: SelectableText((_data[index] as CompletionItem).text),
    );
  }

  Widget _buildErrorItem(BuildContext context, int index) {
    final myColors = Theme.of(context).extension<MyColors>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: myColors?.completionBackgroundColor,
      child: Column(
        children: [
          Text(
            'Error',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          SelectableText(
            (_data[index] as ErrorItem).error.message ??
                (_data[index] as ErrorItem).error.error ??
                'ERROR!',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            selectionControls:
                Platform.isIOS ? myCupertinoTextSelectionControls : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptInput(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            maxLines: 6,
            minLines: 1,
            autofocus: true,
            decoration: InputDecoration(
              hintText: S.of(context).prompt,
              contentPadding: const EdgeInsets.only(left: 16.0),
            ),
            controller: _msgController,
            selectionControls:
                Platform.isIOS ? myCupertinoTextSelectionControls : null,
            onChanged: (value) {
              if (value.isNotBlank) {
                if (!_isRequesting) {
                  if (!_isEnabledSendButton()) {
                    setState(() {
                      _inputMessage = value;
                    });
                  }
                }
              } else {
                if (!_isRequesting) {
                  if (_isEnabledSendButton()) {
                    setState(() {
                      _inputMessage = value;
                    });
                  }
                }
              }
            },
          ),
        ),
        IconButton(
          onPressed: !_isEnabledSendButton()
              ? null
              : () {
                  setState(() {
                    _isRequesting = true;
                    _inputMessage = _msgController.text.trim();
                    var promptItem = PromptItem(
                        inputMessage: _inputMessage,
                        appendedPrompt: _appendPrompt());
                    _data.add(promptItem);
                    _sendPrompt(promptItem);
                    _msgController.clear();
                  });
                  _scrollToEnd();
                },
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _listController.dispose();
    _gpt3FocusNode.dispose();
    super.dispose();
  }
}

abstract class ListItem {}

class PromptItem extends ListItem {
  // final String model;
  final String inputMessage;
  final String appendedPrompt;
  // final DateTime dateTime;
  // final double temperature;
  // final int maxTokens;

  PromptItem({
    // required this.model,
    required this.inputMessage,
    required this.appendedPrompt,
    // required this.dateTime,
    // required this.temperature,
    // required this.maxTokens
  });
}

class CompletionItem extends ListItem {
  final PromptItem promptItem;

  // final String object;
  // final DateTime dateTime;
  final String text;

  // final String finishReason;

  CompletionItem({
    required this.promptItem,
    // required this.object,
    // required this.dateTime,
    required this.text,
    // required this.finishReason
  });
}

class ErrorItem extends ListItem {
  final DioErrorEntity error;

  ErrorItem(this.error);
}
