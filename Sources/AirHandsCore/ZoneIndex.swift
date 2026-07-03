public struct Zone: Codable, Sendable {
    public var id: String
    public var rect: Rect
    /// Higher layer wins hit-tests (e.g. black piano keys over white).
    public var layer: Int

    public init(id: String, rect: Rect, layer: Int) {
        self.id = id
        self.rect = rect
        self.layer = layer
    }
}

private func inRect(_ p: Point, _ r: Rect) -> Bool {
    p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height
}

public final class ZoneIndex {
    private let zones: [Zone]
    private let byId: [String: Zone]

    public init(_ zones: [Zone]) {
        // Sorted once so zoneAt returns the highest layer without a full scan pass.
        self.zones = zones.sorted { $0.layer > $1.layer }
        self.byId = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
    }

    public func zoneAt(_ p: Point) -> Zone? {
        zones.first { inRect(p, $0.rect) }
    }

    /// Membership test, optionally inflating the rect by a fraction of its own size (hysteresis).
    public func contains(_ zoneId: String, _ p: Point, inflateBy: Double = 0) -> Bool {
        guard let zone = byId[zoneId] else { return false }
        if inflateBy == 0 { return inRect(p, zone.rect) }
        let dx = zone.rect.width * inflateBy
        let dy = zone.rect.height * inflateBy
        return inRect(
            p,
            Rect(
                x: zone.rect.x - dx,
                y: zone.rect.y - dy,
                width: zone.rect.width + 2 * dx,
                height: zone.rect.height + 2 * dy
            )
        )
    }
}
