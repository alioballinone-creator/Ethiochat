import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class ArticleReaderScreen extends StatefulWidget {
  const ArticleReaderScreen({
    super.key,
    required this.accountId,
    required this.articleIndex,
  });

  final String accountId;
  final int articleIndex;

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  var _saved = false;
  var _liked = false;
  var _fontStep = 0;

  DemoArticle get _article {
    final articles = DemoContent.officialAccount(widget.accountId).articles;
    return articles[widget.articleIndex.clamp(0, articles.length - 1)];
  }

  DemoOfficialAccount get _account =>
      DemoContent.officialAccount(widget.accountId);

  double get _bodySize => (16 + _fontStep * 1.5).clamp(14, 22).toDouble();

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: '${_article.title}\n\n${_article.body}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final article = _article;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: _saved ? 'Remove bookmark' : 'Save article',
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? EthioColors.goldDeep : null,
            ),
            onPressed: () => setState(() => _saved = !_saved),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _copy,
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: ListView(
            padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: Sp.x2,
                      runSpacing: Sp.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Sp.x2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pal.chip,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(article.category, style: text.labelSmall),
                        ),
                        Text(
                          article.date,
                          style: text.labelSmall
                              ?.copyWith(color: pal.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Smaller text',
                    onPressed: _fontStep <= -1
                        ? null
                        : () => setState(() => _fontStep--),
                    icon: const Icon(Icons.text_decrease_rounded),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    onPressed: _fontStep >= 1
                        ? null
                        : () => setState(() => _fontStep++),
                    icon: const Icon(Icons.text_increase_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x2),
              Text(article.title, style: text.headlineMedium),
              const SizedBox(height: Sp.x2),
              Text(
                article.summary,
                style: text.bodyLarge?.copyWith(
                  color: pal.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: Sp.x4),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: Rad.r18,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      EthioColors.goldDeep.withValues(alpha: 0.72),
                      EthioColors.blackSoft,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _account.category == 'News'
                        ? Icons.newspaper_rounded
                        : _account.category == 'Banking'
                            ? Icons.account_balance_rounded
                            : Icons.cell_tower_rounded,
                    size: 58,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x4),
              Text(
                article.body,
                style: text.bodyLarge?.copyWith(
                  fontSize: _bodySize,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: Sp.x4),
              Divider(color: pal.line),
              const SizedBox(height: Sp.x2),
              Row(
                children: [
                  CircleAvatar(child: Text(_account.name.substring(0, 1))),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _account.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium,
                              ),
                            ),
                            if (_account.verified) ...[
                              const SizedBox(width: Sp.x1),
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: EthioColors.goldDeep,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Verified ${_account.category.toLowerCase()} account',
                          style: text.labelSmall
                              ?.copyWith(color: pal.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '/discover/official/${_account.id}',
                    ),
                    child: const Text('View'),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x4),
              Row(
                children: [
                  Expanded(
                    child: EthioButton(
                      label: _liked ? 'Liked' : 'Like this article',
                      kind: _liked
                          ? EthioButtonKind.secondary
                          : EthioButtonKind.primary,
                      icon: _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      onPressed: () => setState(() => _liked = !_liked),
                    ),
                  ),
                  const SizedBox(width: Sp.x2),
                  IconButton.outlined(
                    tooltip: 'Copy article',
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x4),
              Center(
                child: Text(
                  'Report inaccurate information with the account menu.',
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(color: pal.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
