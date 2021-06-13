import Foundation
import os.log

class SsDirectoryParserDelegate: SsSongParserDelegate {
    
    let directory: Directory?
    let musicFolder: MusicFolder?
    
    let directoriesBeforeFetch: Set<Directory>
    var directoriesParsed = Set<Directory>()
    let songsBeforeFetch: Set<Song>
    var songsParsed = Set<Song>()
    
    init(directory: Directory, library: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator) {
        self.directory = directory
        self.musicFolder = nil
        directoriesBeforeFetch = Set(directory.subdirectories)
        songsBeforeFetch = Set(directory.songs)
        super.init(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
    }
    
    init(musicFolder: MusicFolder, library: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator) {
        self.directory = nil
        self.musicFolder = musicFolder
        directoriesBeforeFetch = Set(musicFolder.directories)
        songsBeforeFetch = Set(musicFolder.songs)
        super.init(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "child" {
            if let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool {
                if let id = attributeDict["id"], let title = attributeDict["title"] {
                    var parsedDirectory: Directory!
                    if let fetchedDirectory = library.getDirectory(id: id) {
                        parsedDirectory = fetchedDirectory
                    } else {
                        parsedDirectory = library.createDirectory()
                        parsedDirectory.id = id
                        parsedDirectory.name = title
                        if let coverArtId = attributeDict["coverArt"] {
                            parsedDirectory.artwork = parseArtwork(id: coverArtId)
                        }
                    }
                        
                    if let directory = directory {
                        directory.managedObject.addToSubdirectories(parsedDirectory.managedObject)
                    } else if let musicFolder = musicFolder {
                        musicFolder.managedObject.addToDirectories(parsedDirectory.managedObject)
                    }
                    directoriesParsed.insert(parsedDirectory)
                }
            } else if let song = songBuffer {
                if let directory = directory {
                    directory.managedObject.addToSongs(song.managedObject)
                    songsParsed.insert(song)
                } else if let musicFolder = musicFolder {
                    musicFolder.managedObject.addToSongs(song.managedObject)
                    songsParsed.insert(song)
                }
            }
        }
        if elementName == "artist" {
            if let id = attributeDict["id"], let name = attributeDict["name"] {
                var parsedDirectory: Directory!
                if let fetchedDirectory = library.getDirectory(id: id) {
                    parsedDirectory = fetchedDirectory
                } else {
                    parsedDirectory = library.createDirectory()
                    parsedDirectory.id = id
                    parsedDirectory.name = name
                }

                if let directory = directory {
                    directory.managedObject.addToSubdirectories(parsedDirectory.managedObject)
                } else if let musicFolder = musicFolder {
                    musicFolder.managedObject.addToDirectories(parsedDirectory.managedObject)
                }
                directoriesParsed.insert(parsedDirectory)
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "indexes" || elementName == "directory" {
            let removedDirectories = directoriesBeforeFetch.subtracting(directoriesParsed)
            removedDirectories.forEach{ library.deleteDirectory(directory: $0) }
            
            if let directory = self.directory {
                let removedSongs = songsBeforeFetch.subtracting(songsParsed)
                removedSongs.forEach{ directory.managedObject.removeFromSongs($0.managedObject) }
            } else if let musicFolder = musicFolder {
                let removedSongs = songsBeforeFetch.subtracting(songsParsed)
                removedSongs.forEach{ musicFolder.managedObject.removeFromSongs($0.managedObject) }
            }
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
