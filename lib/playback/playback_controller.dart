import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:tempus/app_state.dart';
import 'package:tempus/audio.dart';
import 'package:tempus/playback/bpm_dial.dart';
import 'package:tempus/settings/settings.dart';

class PlaybackController extends StatefulWidget {
  const PlaybackController({super.key});

  @override
  State<StatefulWidget> createState() => PlaybackControllerState();
}

class PlaybackControllerState extends State<PlaybackController> {
  int bpm = 120;
  bool playback = false;
  String feedback = "";

  @override
  void initState() {
    super.initState();
    setBpm(bpm);
  }

  onDialChanged(int change) {
    setBpm(bpm + change);
  }

  setBpm(int newBpm) {
    setState(() => newBpm > 0 ? bpm = newBpm : 1);
    Audio.setBpm(bpm);
  }

  sendFeedback() {
    print("Sent feedback \"$feedback\"");
    Navigator.pop(context);
  }

  setFeedback(String feedback) {
    this.feedback = feedback;
  }

  togglePlayback() {
    playback ? Audio.stopPlayback() : Audio.startPlayback();
    setState(() {
      playback = !playback;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlatformIconButton(
                  icon: Icon(
                    PlatformIcons(context).remove,
                    color: Theme.of(context).colorScheme.primary,
                    size: 35,
                  ),
                  onPressed: () => setBpm(bpm - 1),
                ),
                Container(
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary),
                        borderRadius: BorderRadius.circular(8.0)),
                    width: 100,
                    height: 60,
                    child: Center(
                        child: Text(
                      bpm.toString(),
                      style: TextStyle(
                          fontSize: 35,
                          color: Theme.of(context).colorScheme.primary),
                      textAlign: TextAlign.center,
                    ))),
                PlatformIconButton(
                    icon: Icon(PlatformIcons(context).add,
                        color: Theme.of(context).colorScheme.primary, size: 35),
                    onPressed: () => setBpm(bpm + 1)),
              ],
            ),
          ),
          Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                        width: constraints.maxHeight / 3 * 2,
                        height: constraints.maxWidth / 3 * 2,
                        child: BpmDial(
                            callbackThreshold: 20, callback: onDialChanged)),
                  ),
                  Center(
                      child: PlatformIconButton(
                    icon: Icon(
                        size: 80,
                        playback
                            ? PlatformIcons(context).pause
                            : PlatformIcons(context).playArrowSolid,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: togglePlayback,
                  )),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              PlatformIconButton(
                                  icon: Icon(
                                    PlatformIcons(context).settings,
                                    size: 40,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        builder: (BuildContext context) =>
                                            Settings());
                                  }),
                              PlatformIconButton(
                                  icon: Icon(
                                    PlatformIcons(context).help,
                                    size: 40,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () => showFeedbackDialog(
                                      context, setFeedback, sendFeedback)),
                            ]),
                      ),
                    ],
                  )
                ],
              )),
        ],
      );
    });
  }
}

showFeedbackDialog(BuildContext context, Function setFeedbackCallback,
    Function sendFeedbackCallback) {
  showPlatformDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
              title: Text("Feedback Form"),
              content: Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),
                  child: PlatformTextField(
                    hintText: "Issues, feature requests, ...",
                    onChanged: (text) => setFeedbackCallback(text),
                  )),
              actions: [
                PlatformDialogAction(
                    child: Text("Close"),
                    onPressed: () => Navigator.pop(context),
                    cupertino: (context, platform) =>
                        CupertinoDialogActionData(isDestructiveAction: true)),
                PlatformDialogAction(
                    child: Text("Submit"),
                    onPressed: () => sendFeedbackCallback(),
                    cupertino: (context, platform) =>
                        CupertinoDialogActionData(isDefaultAction: true))
              ]));
}
