import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:keyboard_actions/keyboard_actions.dart';

import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/models/routine.dart';

class PartEditPage extends StatefulWidget {
  final Part part;
  final AddOrEdit addOrEdit;
  final Routine curRoutine;

  const PartEditPage({
    required this.addOrEdit,
    required this.part,
    required this.curRoutine
  });

  @override
  State<StatefulWidget> createState() => _PartEditPageState();
}

typedef MaterialCallback = Widget Function();

class Item {
  bool isExpanded;
  final String header;
  final Widget body;
  final Icon iconpic;
  final MaterialCallback callback;
  Item({
    required this.isExpanded,
    required this.header,
    required this.body,
    required this.iconpic,
    required this.callback
  });
}

class _PartEditPageState extends State<PartEditPage> {
  final additionalNotesTextEditingController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late Routine curRoutine;
  List<TextEditingController> textControllers = <TextEditingController>[];
  List<FocusNode> focusNodes = <FocusNode>[];
  int radioValueTargetedBodyPart = 0;
  int radioValueSetType = 0;
  bool additionalNotesIsExpanded = false;
  bool isNewlyCreated = false;
  late List<Item> items;
  List<Exercise> tempExs = <Exercise>[];
  late SetType setType;

  ///the widgets that are gonna be displayed in the expansionPanel of exercise detail
  List<bool> enabledList = <bool>[true, false, false, false];

  @override
  void initState() {
    ///copy the content of exercises of the Part
    additionalNotesIsExpanded = false;

    additionalNotesTextEditingController.text = widget.part.additionalNotes;

    //Determine whether or not the exercise is newly created.
    if (widget.part.exercises.isEmpty) {
      for (int i = 0; i < 4; i++) {
        var exCopy = Exercise(name: '', weight: 0, sets: 0, reps: '', exHistory: {});
        tempExs.add(exCopy);
      }
      isNewlyCreated = true;
    } else {
      //if the part is an existing part that's been editing, then copy the whole thing to _tempExs
      for (int i = 0; i < 4; i++) {
        if (i < widget.part.exercises.length) {
          var ex = widget.part.exercises[i];
          var exCopy = Exercise(
              name: ex.name,
              weight: ex.weight,
              sets: ex.sets,
              reps: ex.reps,
              workoutType: ex.workoutType,
              exHistory: ex.exHistory);
          tempExs.add(exCopy);
        } else {
          tempExs.add(Exercise(name: '', weight: 0, sets: 0, reps: '', exHistory: {}));
        }
      }
      isNewlyCreated = false;
    }

    setType = isNewlyCreated ? SetType.Regular : widget.part.setType;

    if (true) {
      switch (widget.part.targetedBodyPart) {
        case TargetedBodyPart.Abs:
          radioValueTargetedBodyPart = 0;
          break;
        case TargetedBodyPart.Arm:
          radioValueTargetedBodyPart = 1;
          break;
        case TargetedBodyPart.Back:
          radioValueTargetedBodyPart = 2;
          break;
        case TargetedBodyPart.Chest:
          radioValueTargetedBodyPart = 3;
          break;
        case TargetedBodyPart.Leg:
          radioValueTargetedBodyPart = 4;
          break;
        case TargetedBodyPart.Shoulder:
          radioValueTargetedBodyPart = 5;
          break;
        case TargetedBodyPart.Bicep:
          radioValueTargetedBodyPart = 6;
          break;
        case TargetedBodyPart.Tricep:
          radioValueTargetedBodyPart = 7;
          break;
        case TargetedBodyPart.FullBody:
          radioValueTargetedBodyPart = 8;
          break;
      }

      switch (widget.part.setType) {
        case SetType.Regular:
          radioValueSetType = 0;
          break;
        case SetType.Drop:
          radioValueSetType = 1;
          break;
        case SetType.Super:
          radioValueSetType = 2;
          break;
        case SetType.Tri:
          radioValueSetType = 3;
          break;
        case SetType.Giant:
          radioValueSetType = 4;
          break;
      }

      for (int i = 0; i < 16; i++) {
        textControllers.add(TextEditingController());
      }

      for (int i = 0, j = 0; i < 16; i++, j += 4) {
        if (i < widget.part.exercises.length) {
          textControllers[j].text = widget.part.exercises[i].name;
          textControllers[j + 1].text = widget.part.exercises[i].weight.toString();
          textControllers[j + 2].text = widget.part.exercises[i].sets.toString();
          textControllers[j + 3].text = widget.part.exercises[i].reps;
        }
      }

      textControllers.forEach((_) {
        focusNodes.add(FocusNode());
      });
    }

    //_widgets = buildSetDetails(isNewlyCreated ? SetType.Regular : widget.part.setType);

    items = <Item>[
      Item(
          isExpanded: true,
          header: 'Targeted Muscle Group',
          body: Container(), // Add an empty container or appropriate widget
          callback: buildTargetedBodyPartRadioList,
          iconpic: const Icon(Icons.accessibility_new)),
      Item(
          isExpanded: false,
          header: 'Set Type',
          body: Container(), // Add an empty container or appropriate widget
          callback: buildSetTypeList,
          iconpic: const Icon(Icons.blur_linear)),
      Item(
          isExpanded: true,
          header: 'Set Details',
          body: Container(), // Add an empty container or appropriate widget
          callback: buildSetDetailsList,
          iconpic: const Icon(Icons.fitness_center))
    ];

    super.initState();
  }

  Future<bool> onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Your editing will not be saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              if (widget.addOrEdit == AddOrEdit.add) widget.curRoutine.parts.removeLast();
              Navigator.of(context).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget buildTargetedBodyPartRadioList() {
    return Material(
      color: Colors.transparent,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: <Widget>[
            RadioListTile<int>(value: 0, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Abs')),
            RadioListTile<int>(value: 1, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Arm')),
            RadioListTile<int>(value: 2, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Back')),
            RadioListTile<int>(value: 3, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Chest')),
            RadioListTile<int>(value: 4, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Leg')),
            RadioListTile<int>(value: 5, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Shoulder')),
            RadioListTile<int>(value: 6, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Bicep')),
            RadioListTile<int>(value: 7, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Tricep')),
            RadioListTile<int>(value: 8, groupValue: radioValueTargetedBodyPart, onChanged: onRadioValueChanged, title: const Text('Full Body')),
          ])),
    );
  }

  Widget buildSetTypeList() {
    const selectedTextStyle = TextStyle(fontSize: 16);
    const unselectedTextStyle = TextStyle(fontSize: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<SetType>(
          children: {
            SetType.Regular: Text('Regular', style: this.setType == SetType.Regular ? selectedTextStyle : unselectedTextStyle),
            SetType.Super: Text('Super', style: this.setType == SetType.Super ? selectedTextStyle : unselectedTextStyle),
            SetType.Tri: Text('Tri', style: this.setType == SetType.Tri ? selectedTextStyle : unselectedTextStyle),
            SetType.Giant: Text('Giant', style: this.setType == SetType.Giant ? selectedTextStyle : unselectedTextStyle),
            SetType.Drop: Text('Drop', style: this.setType == SetType.Drop ? selectedTextStyle : unselectedTextStyle)
          },
          onValueChanged: (setType) {
            if (setType != null) {
              setState(() {
                this.setType = setType;
              });
            }
          },
          thumbColor: setTypeToColorConverter(this.setType),
          groupValue: setType,
        ),
      ),
    );
  }

  ///Build the expansion panel for detailed information on exercises
  Widget buildSetDetailsList() {
    return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: buildSetDetails()),
        ));
  }

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: focusNodes.map((node) {
        return KeyboardActionsItem(
          focusNode: node,
          toolbarButtons: [
            // Add your custom actions if needed
                (node) {
              return GestureDetector(
                onTap: () => node.unfocus(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.close),
                ),
              );
            }
          ],
        );
      }).toList(),
    );
  }

  List<Widget> buildSetDetails() {
    const count = 4;

    List<Widget> widgets = <Widget>[];

    int exCount = setTypeToExerciseCountConverter(setType);

    for (int i = 0; i < 4; i++) {
      if (i < exCount) {
        enabledList[i] = true;
      } else {
        enabledList[i] = false;
      }
    }

    //setType will not be passed in when initializing this page
    for (int i = 0, j = 0; i < count; i++, j += 4) {
      if (enabledList[i]) {
        widgets.add(Text('Exercise ' + (i + 1).toString()));
        widgets.add(Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              const Expanded(
                  child: Text(
                    'Rep',
                    textAlign: TextAlign.center,
                  )),
              Expanded(
                child: Switch(
                  value: tempExs[i].workoutType == WorkoutType.Cardio,
                  onChanged: (res) {
                    setState(() {
                      tempExs[i].workoutType = res ? WorkoutType.Cardio : WorkoutType.Weight;
                    });
                  },
                  inactiveThumbColor: Colors.red,
                  inactiveTrackColor: Colors.redAccent,
                ),
              ),
              const Expanded(
                child: Text(
                  'Sec',
                  textAlign: TextAlign.center,
                ),
              )
            ],
          ),
        ));
        widgets.add(Builder(
          builder: (context) => TextFormField(
            controller: textControllers[j],
            focusNode: focusNodes[j],
            style: const TextStyle(fontSize: 18),
            onFieldSubmitted: (str) {
              setState(() {
                //widget.part.exercises[i].name = str;
              });
            },
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (str) {
              if (str == null || str.isEmpty) {
                return 'Please enter the name of exercise';
              } else {
                tempExs[i].name = textControllers[j].text;
                return null;
              }
            },
          ),
        ));
        widgets.add(Row(
            children: <Widget>[
        Flexible(
        child: Builder(
            builder: (context) => TextFormField(
        controller: textControllers[j + 1],
        focusNode: focusNodes[j + 1],
            onFieldSubmitted: (str) {},
    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
    textInputAction: TextInputAction.done,
    decoration: const InputDecoration(labelText: 'Weight'),
    style: const TextStyle(fontSize: 20),
    validator: (str) {
    if (str == null || str.isEmpty) {
    tempExs[i].weight = 0;
    return null;
    } else if (str.contains(RegExp(r"(,|-)"))) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    backgroundColor: Colors.red,
    content: Row(
    children: <Widget>[
    Padding(
    padding: EdgeInsets.only(right: 4),
    child: Icon(Icons.report),
    ),
    Text("Weight can only contain numbers.")
    ],
    ),
    ));
    return "Numbers only";
    } else {
    try {
    double tempWeight = double.parse(textControllers[j + 1].text);
    //the weight below 20 doesn't need floating point, it's just unnecessary
    if (tempWeight < 20) {
      tempExs[i].weight = tempWeight;
    } else {
      tempExs[i].weight = tempWeight.floorToDouble();
    }

    return null;
    } catch (Exception) {
      return "Invalid number format";
    }
    }
    },
      )),
      ),
      Flexible(
      child: TextFormField(
      controller: textControllers[j + 2],
      focusNode: focusNodes[j + 2],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (str) {},
      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: const InputDecoration(labelText: 'Sets'),
      style: const TextStyle(fontSize: 20),
      validator: (str) {
      if (str == null || str.isEmpty) {
      tempExs[i].sets = 1; //number of sets must be none zero
      return null;
      } else if (str.contains(RegExp(r"(,|\.|-)"))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Sets can only contain numbers."),
      ));
      return "Numbers only";
      } else {
      tempExs[i].sets = int.parse(textControllers[j + 2].text);
      return null;
      }
      },
      ),
      ),
      Flexible(
      child: TextFormField(
      controller: textControllers[j + 3],
      focusNode: focusNodes[j + 3],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (str) {},
      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(labelText: tempExs[i].workoutType == WorkoutType.Weight ? 'Reps' : 'Seconds'),
      style: const TextStyle(fontSize: 20),
      validator: (str) {
      if (str == null || str.isEmpty) {
      return 'Cannot be empty';
      } else {
      tempExs[i].reps = textControllers[j + 3].text;
      return null;
      }
      },
      ),
      )
      ],
      ));
      widgets.add(Container(
      //serve as divider
      height: 24,
      ));
    }
            }
            return widgets;
            }

            ScrollController? scrollController;

            @override
            Widget build(BuildContext context) {
          var children = <Widget>[];
          for (Item item in items) {
            children.add(ListTile(
                leading: item.iconpic,
                title: Text(item.header,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w400,
                    ))));
            children.add(item.callback());
          }

          var listView = KeyboardActions(
            config: _buildConfig(context),
            child: Column(
              children: [
                Form(
                    key: formKey,
                    child: const Padding(
                      //Targeted Body Part, Type of set, Details
                        padding: EdgeInsets.all(0),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [],
                          ),
                        ))),
              ],
            ),
          );

          // Fix the Form widget as it's currently not using children
          listView = KeyboardActions(
            config: _buildConfig(context),
            child: Column(
              children: [
                Form(
                    key: formKey,
                    child: Padding(
                      //Targeted Body Part, Type of set, Details
                        padding: const EdgeInsets.all(0),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: children,
                          ),
                        ))),
              ],
            ),
          );

          var scaffold = Scaffold(
            key: scaffoldKey,
            appBar: AppBar(title: const Text("Criteria Selection"), actions: <Widget>[
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.done),
                    onPressed: () {
                      if (formKey.currentState != null && formKey.currentState!.validate()) {
                        widget.part.targetedBodyPart = PartEditPageHelper.radioValueToTargetedBodyPartConverter(radioValueTargetedBodyPart);
                        widget.part.setType = setType;
                        widget.part.exercises = <Exercise>[];
                        for (int i = 0; i < enabledList.where((res) => res).length; i++) {
                          widget.part.exercises.add(Exercise(
                              name: tempExs[i].name,
                              weight: tempExs[i].weight,
                              sets: tempExs[i].sets,
                              reps: tempExs[i].reps,
                              workoutType: tempExs[i].workoutType,
                              exHistory: tempExs[i].exHistory));
                        }
                        widget.part.additionalNotes = additionalNotesTextEditingController.text;
                        Navigator.pop(context, widget.part);
                      }
                    },
                  );
                },
              )
            ]),
            body: listView,
          );
          return WillPopScope(onWillPop: onWillPop, child: scaffold);
        }

        void onRadioValueChanged(int? value) {
          if (value != null) {
            setState(() {
              radioValueTargetedBodyPart = value;
            });
          }
        }

        void onRadioSetTypeValueChanged(int? value) {
          if (value != null) {
            setState(() {
              radioValueSetType = value;
              setType = PartEditPageHelper.radioValueToSetTypeConverter(value);
            });
          }
        }
      }

  class PartEditPageHelper {
  static SetType radioValueToSetTypeConverter(int radioValue) {
  switch (radioValue) {
  case 0:
  return SetType.Regular;
  case 1:
  return SetType.Drop;
  case 2:
  return SetType.Super;
  case 3:
  return SetType.Tri;
  case 4:
  return SetType.Giant;
  default:
  throw Exception('Inside _radioValueToSetTypeConverter');
  }
  }

  static TargetedBodyPart radioValueToTargetedBodyPartConverter(int radioValue) {
  switch (radioValue) {
  case 0:
  return TargetedBodyPart.Abs;
  case 1:
  return TargetedBodyPart.Arm;
  case 2:
  return TargetedBodyPart.Back;
  case 3:
  return TargetedBodyPart.Chest;
  case 4:
  return TargetedBodyPart.Leg;
  case 5:
  return TargetedBodyPart.Shoulder;
  case 6:
  return TargetedBodyPart.Bicep;
  case 7:
  return TargetedBodyPart.Tricep;
  case 8:
  return TargetedBodyPart.FullBody;
  default:
  throw Exception('Inside _radioValueToTargetedBodyPartConverter, radioValue: ${radioValue.toString()}');
  }
  }
  }