import 'package:flutter/cupertino.dart';

class CupertinoListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const CupertinoListTile({
    Key? key,
    this.leading,
    required this.title,
    required this.subtitle,
    this.trailing
  }) : super(key: key);

  @override
  _StatefulStateCupertino createState() => _StatefulStateCupertino();
}

class _StatefulStateCupertino extends State<CupertinoListTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (widget.leading != null) widget.leading!,
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.title,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 25,
                      )),
                  Text(widget.subtitle,
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 20,
                      )),
                ],
              ),
            ],
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}