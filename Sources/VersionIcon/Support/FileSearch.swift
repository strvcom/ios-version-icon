import Files

extension Folder {
    func findFirstFile(name: String) -> File? {
        for file in files.recursive where file.name == name {
            return file
        }

        return nil
    }

    func findFirstFolder(name: String) -> Folder? {
        if self.name == name {
            return self
        }

        for folder in subfolders.recursive where folder.name == name {
            return folder
        }

        return nil
    }
}
