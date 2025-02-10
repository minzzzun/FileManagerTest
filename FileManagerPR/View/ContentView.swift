import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ImageViewModel()
    @State private var showImagePicker = false

    var body: some View {
        NavigationView {
            VStack {
                // ✅ 사용자가 선택한 이미지 표시
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 250)
                        .cornerRadius(10)
                } else {
                    Text("이미지를 선택하세요")
                        .foregroundColor(.gray)
                }

                Button("새로고침"){
                    viewModel.loadImagesFromICloud()
                }
                
                HStack {
                    Button("사진 선택") {
                        showImagePicker.toggle()
                    }
                    .padding()

                    Button("iCloud 저장") {
                        if let image = viewModel.selectedImage {
                            let fileName = "image_\(UUID().uuidString).jpg"
                            viewModel.saveImageToICloud(image: image, fileName: fileName)
                        }
                    }
                    .padding()
                }

                List {
                    ForEach(viewModel.savedImages) { imageFile in
                        HStack {
                            if let image = viewModel.loadImage(from: imageFile.filePath) {
                                // ✅ 이미지 선택 버튼 (독립적인 터치 감지)
                                Button(action: {
                                    viewModel.selectedImage = image
                                }) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle()) // ✅ 버튼 스타일 변경하여 동작 분리
                                .contentShape(Rectangle()) // ✅ 터치 영역 명확하게 설정
                            }

                            Text(imageFile.fileName)
                                .font(.caption)

                            Spacer()

                            // ✅ 삭제 버튼을 별도의 `Button`으로 분리하여 터치 충돌 방지
                            Button(action: {
                                viewModel.deleteFileFromICloud(fileName: imageFile.fileName)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // ✅ 버튼 스타일 변경하여 UI 자연스럽게
                        }
                    }
                }
                .onAppear {
                    viewModel.loadImagesFromICloud()
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $viewModel.selectedImage)
            }
            .navigationTitle("iCloud 이미지 관리")
        }
    }
}

