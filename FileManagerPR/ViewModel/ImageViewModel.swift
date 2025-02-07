import SwiftUI

class ImageViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var savedImages: [ImageFile] = []
    
    init() {
        createICloudFolderIfNeeded()
        loadImagesFromICloud()  // ✅ 앱 실행 시 자동으로 목록 불러오기
    }

    /// 📌 iCloud Drive 저장 경로 가져오기
    private func getICloudDirectory() -> URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    /// 📌 iCloud Drive에 `Documents` 폴더가 없으면 생성
    private func createICloudFolderIfNeeded() {
        guard let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }

        if !FileManager.default.fileExists(atPath: iCloudURL.path) {
            do {
                try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ iCloud Drive 폴더 생성됨: \(iCloudURL.path)")
            } catch {
                print("❌ iCloud Drive 폴더 생성 실패: \(error.localizedDescription)")
            }
        } else {
            print("✅ iCloud Drive 폴더가 이미 존재함: \(iCloudURL.path)")
        }
    }

    /// 📌 iCloud Drive에 이미지 저장 + ✅ 저장 후 자동 새로고침
    func saveImageToICloud(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 1.0),
              let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }
        
        let fileName = "image_\(UUID().uuidString).jpg"
        let fileURL = iCloudURL.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            print("✅ iCloud Drive에 저장됨: \(fileURL)")

            DispatchQueue.main.async {
                self.loadImagesFromICloud() // ✅ 저장 후 자동으로 목록 새로고침
            }
        } catch {
            print("❌ iCloud 저장 실패: \(error.localizedDescription)")
        }
    }

    /// 📌 iCloud Drive에서 이미지 불러오기
    func loadImagesFromICloud() {
        guard let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)
            DispatchQueue.main.async {
                self.savedImages = fileURLs.map { url in
                    ImageFile(fileName: url.lastPathComponent, filePath: url, createdAt: Date())
                }
            }
            print("✅ iCloud Drive에서 이미지 목록 불러오기 성공")
        } catch {
            print("❌ iCloud 목록 불러오기 실패: \(error.localizedDescription)")
        }
    }

    /// 📌 iCloud Drive에서 특정 파일 삭제 + ✅ 삭제 후 자동 새로고침
    func deleteFileFromICloud(fileName: String) {
        guard let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }

        let fileURL = iCloudURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑 ✅ 파일 삭제 성공: \(fileURL.path)")

                DispatchQueue.main.async {
                    self.loadImagesFromICloud() // ✅ 삭제 후 자동으로 목록 새로고침
                }
            } else {
                print("⚠️ 삭제하려는 파일이 존재하지 않음: \(fileURL.path)")
            }
        } catch {
            print("❌ 파일 삭제 실패: \(error.localizedDescription)")
        }
    }

    /// 📌 저장된 이미지 불러오기
    func loadImage(from filePath: URL) -> UIImage? {
        if let data = try? Data(contentsOf: filePath) {
            return UIImage(data: data)
        }
        return nil
    }
}

