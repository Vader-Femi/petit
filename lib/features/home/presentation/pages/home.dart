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
              getHomeViewModel.showResult(null);
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
                          "Select image(s) to compress",
                          style: TextStyle(fontSize: 18),
                        )
                      : Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: getHomeViewModel.pickedImages.length,
                            itemBuilder: (context, index) {
                              var imageData = getHomeViewModel.pickedImages
                                  .elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Image.file(
                                  imageData.imageFile,
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                  Spacer(),
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
      floatingActionButton: SuperBuilder(
        builder: (context) {
          return getHomeViewModel.pickedImages.isEmpty
              ? FloatingActionButton(
                  onPressed: () async {
                    if (!getHomeViewModel.isLoading.state) {
                      await getHomeViewModel.pickMultipleImages();
                    }
                  },
                  child: Icon(Icons.add_photo_alternate_outlined),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                        onPressed: () async {
                          if (!getHomeViewModel.isLoading.state) {
                            await getHomeViewModel.pickMultipleImages();
                          }
                        },
                        child: Icon(Icons.add_photo_alternate_outlined)),
                    SizedBox(height: 10),
                    FloatingActionButton.extended(
                      icon: Icon(Icons.compress_outlined),
                      onPressed: () async {
                        if (!getHomeViewModel.isLoading.state) {
                          if (getHomeViewModel.pickedImages.isEmpty) {
                            await getHomeViewModel
                                .showResult("Select images first");
                            return;
                          }

                          getHomeViewModel.setIsLoading(true);
                          for (var imageData
                              in getHomeViewModel.pickedImages.state) {
                            await getHomeViewModel
                                .compressImage(imageData: imageData)
                                .then((compressedFile) async {
                              await getHomeViewModel
                                  .saveLocalImage(compressedFile)
                                  .then((onValue) async {
                                getHomeViewModel
                                    .showResult("Image(s) Saved to Galery!");
                                getHomeViewModel.pickedImages.state = [];
                                getHomeViewModel.setIsLoading(false);
                              });
                            });
                          }
                        }
                      },
                      label: const Text('Compress'),
                    ),
                  ],
                );
        },
      ),
    );
  }
}
