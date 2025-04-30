import 'package:flutter/cupertino.dart';
// Import Material for InkWell if needed, or use CupertinoButton

/// A reusable list tile widget styled similarly to iOS list items.
class CupertinoListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap; // Optional tap callback
  final EdgeInsetsGeometry padding; // Customizable padding
  final double minLeadingWidth; // Customizable minimum width for leading area

  const CupertinoListTile({
    super.key,
    this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    // Default padding similar to Cupertino list items
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    this.minLeadingWidth = 56.0, // Default width to accommodate typical icons + padding
  });

  @override
  Widget build(BuildContext context) {
    // Get text styles from the current Cupertino theme
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color primaryColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final Color secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    final TextStyle titleStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      color: primaryColor,
      fontSize: 17, // Standard iOS size
      // fontWeight: FontWeight.w600, // Optional bold title
    );
    final TextStyle subtitleStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      color: secondaryColor,
      fontSize: 15, // Standard iOS size
    );

    // Build the row content
    Widget content = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          // Leading Widget Area
          if (leading != null)
            Padding(
              // Ensure consistent spacing after leading widget
              padding: const EdgeInsetsDirectional.only(end: 16.0),
              child: leading!,
            )
          // Add SizedBox if no leading widget but you want consistent alignment
          else if (minLeadingWidth > 0)
            SizedBox(width: minLeadingWidth - padding.horizontal / 2), // Adjust for padding

          // Title and Subtitle Area (takes up remaining space)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // Center text vertically if row height allows
              children: <Widget>[
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 1, // Prevent title wrapping by default
                  overflow: TextOverflow.ellipsis, // Handle overflow
                ),
                // Add spacing only if subtitle exists
                if (subtitle.isNotEmpty) const SizedBox(height: 2),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: subtitleStyle,
                    maxLines: 1, // Prevent subtitle wrapping by default
                    overflow: TextOverflow.ellipsis, // Handle overflow
                  ),
              ],
            ),
          ),

          // Trailing Widget Area (if provided)
          if (trailing != null)
            Padding(
              // Ensure consistent spacing before trailing widget
              padding: const EdgeInsetsDirectional.only(start: 16.0),
              child: trailing!,
            ),
        ],
      ),
    );

    // Make the tile tappable if onTap is provided
    if (onTap != null) {
      // Use CupertinoButton for authentic iOS tap feedback, or InkWell for Material look
      return CupertinoButton( // Or GestureDetector
        padding: EdgeInsets.zero, // Remove default button padding
        onPressed: onTap,
        child: content,
        // Optionally add pressed state color:
        // color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context), // Background when pressed
      );
      /* Alternative using InkWell (Material ripple)
      return InkWell(
        onTap: onTap,
        child: content,
      );
      */
    } else {
      // Return content directly if not tappable
      return content;
    }
  }
}