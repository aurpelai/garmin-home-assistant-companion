import Toybox.Lang;

// One array of cards rather than one per type: each card type owns its drawing,
// so the loop needs the sequence and nothing else.
class CardLoopModel {
    public var cards as Array<Card>;

    function initialize(cards as Array<Card>) {
        self.cards = cards;
    }
}
