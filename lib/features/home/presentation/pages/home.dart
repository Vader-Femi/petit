import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Petit"),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 15),
        child: SuperBuilder(builder: (context) {
          if (getHomeViewModel.result.state != null) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("${getHomeViewModel.result.state}"),
              ));
            });
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Spacer(),
                  getHomeViewModel.pickedImages.isEmpty
                      ? const Text(
                          "The selected images will show here",
                          style: TextStyle(fontSize: 18),
                        )
                      : Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: getHomeViewModel.pickedImages.length,
                            itemBuilder: (context, index) {
                              var image = getHomeViewModel.pickedImages
                                  .elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Image.file(
                                  image,
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      var pickedFiles =
                          await getHomeViewModel.pickMultipleFiles();
                      print(pickedFiles.elementAt(0).path);

                      // getHomeViewModel.setIsLoading(true);
                      //
                      // for (var file in pickedFiles) {
                      //   await getHomeViewModel
                      //       .compressImage(file: file, quality: 90)
                      //       .then((compressedFile) async {
                      //     await getHomeViewModel.saveLocalImage(compressedFile);
                      //   });
                      // }
                      //
                      // getHomeViewModel.setIsLoading(false);
                    },
                    child: const Text('Pick images)'),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      if (getHomeViewModel.pickedImages.isEmpty) {
                        getHomeViewModel.showResult("pick images first");
                        return;
                      }

                      getHomeViewModel.setIsLoading(true);

                      for (var file in getHomeViewModel.pickedImages.state) {
                        await getHomeViewModel
                            .compressImage(file: file, quality: 90)
                            .then((compressedFile) async {
                          await getHomeViewModel.saveLocalImage(compressedFile);
                        });
                      }

                      getHomeViewModel.setIsLoading(false);
                    },
                    child: const Text('Compress selected images'),
                  ),
                ],
              ),
              getHomeViewModel.isLoading.state
                  ? SizedBox(
                      width: 35,
                      height: 35,
                      child: CircularProgressIndicator(),
                    )
                  : Container(),
            ],
          );
        }),
      ),
    );
  }
}
