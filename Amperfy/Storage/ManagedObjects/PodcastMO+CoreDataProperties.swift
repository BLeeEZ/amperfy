import Foundation
import CoreData


extension PodcastMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PodcastMO> {
        return NSFetchRequest<PodcastMO>(entityName: "Podcast")
    }

    @NSManaged public var depiction: String?
    @NSManaged public var episodes: NSOrderedSet?
    @NSManaged public var status: Int16
    @NSManaged public var title: String?

}

// MARK: Generated accessors for episodes
extension PodcastMO {

    @objc(insertObject:inEpisodesAtIndex:)
    @NSManaged public func insertIntoEpisodes(_ value: PodcastEpisodeMO, at idx: Int)

    @objc(removeObjectFromEpisodesAtIndex:)
    @NSManaged public func removeFromEpisodes(at idx: Int)

    @objc(insertEpisodes:atIndexes:)
    @NSManaged public func insertIntoEpisodes(_ values: [PodcastEpisodeMO], at indexes: NSIndexSet)

    @objc(removeEpisodesAtIndexes:)
    @NSManaged public func removeFromEpisodes(at indexes: NSIndexSet)

    @objc(replaceObjectInEpisodesAtIndex:withObject:)
    @NSManaged public func replaceEpisodes(at idx: Int, with value: PodcastEpisodeMO)

    @objc(replaceEpisodesAtIndexes:withEpisodes:)
    @NSManaged public func replaceEpisodes(at indexes: NSIndexSet, with values: [PodcastEpisodeMO])

    @objc(addEpisodesObject:)
    @NSManaged public func addToEpisodes(_ value: PodcastEpisodeMO)

    @objc(removeEpisodesObject:)
    @NSManaged public func removeFromEpisodes(_ value: PodcastEpisodeMO)

    @objc(addEpisodes:)
    @NSManaged public func addToEpisodes(_ values: NSOrderedSet)

    @objc(removeEpisodes:)
    @NSManaged public func removeFromEpisodes(_ values: NSOrderedSet)

}
