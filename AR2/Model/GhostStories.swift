//
//  GhostStories.swift
//  AR2
//

import Foundation

// Cerita tiap hantu. Penutupnya menggoda hantu berikutnya di `GhostCatalog.all`, jadi urutan
// katalog membentuk satu benang cerita. Kode gestur tiap hantu harus unik (dicek unit test).
extension GhostStory {
    static let misterQ = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .smile, line: "Sniff… your aura smells sour. Cheer up?", cheer: "Yum!"),
            StoryStep(spot: .shoulder(.right), gesture: .nod, line: "Sweet! Will you be my friend?", cheer: "Friends!"),
            StoryStep(spot: .palm, gesture: .openPalm, line: "Friends share secrets. Let me read your palm…", cheer: "Ooh, fancy!"),
        ],
        finale: "No sadness in your future! But someone is FURIOUS I turned nice…"
    )

    static let trueForm = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .shakeHead, line: "WHO MADE MISTER Q SOFT?! Was it YOU?!", cheer: "Hmph!"),
            StoryStep(spot: .aboveHead, gesture: .punch, line: "Liar! Prove you're brave!", cheer: "OOF!"),
            StoryStep(spot: .shoulder(.left), gesture: .cheekPuff, line: "…Not bad. Now blow my anger away.", cheer: "Phew…"),
        ],
        finale: "Hmph… I'm calm now. In the next grave, a ghost needs a hug."
    )

    static let boo = GhostStory(
        steps: [
            StoryStep(spot: .chest, gesture: .touchGhost, line: "I'm clinging to you! Hug me?", cheer: "Hug!"),
            StoryStep(spot: .besideHead(.left), gesture: .tiltHead, line: "Your hand went through me… Come closer, I'll whisper.", cheer: "Psst!"),
            StoryStep(spot: .inFrontOfFace, gesture: .kiss, line: "Nobody ever hugs me back. A kiss from afar?", cheer: "Mwah!"),
        ],
        finale: "My first hug ever! My friend Wavy still waves at no one…"
    )

    static let wavy = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .wave, line: "Hello? HELLO? Can anybody see me?", cheer: "Hi hi!"),
            StoryStep(spot: .palm, gesture: .peace, line: "YOU CAN SEE ME! Quick, a selfie!", cheer: "Cheese!"),
            StoryStep(spot: .shoulder(.right), gesture: .wink, line: "Only ghost-seers know the secret signal…", cheer: "Hehe!"),
        ],
        finale: "A friend at last! Psst… a cat just fell asleep on your head."
    )

    static let mochi = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .holdStill, line: "Zzz… purrr… (Shh, don't wake her.)", cheer: "Purr…"),
            StoryStep(spot: .palm, gesture: .pinch, line: "*yawn* …Is that tuna? Just a pinch?", cheer: "Tuna!"),
            StoryStep(spot: .shoulder(.left), gesture: .tongueOut, line: "Delicious! Let's groom together.", cheer: "Mlem!"),
        ],
        finale: "Purrfect human. My twin Nori hides in the dark… she loves tricks."
    )

    static let nori = GhostStory(
        steps: [
            StoryStep(spot: .peekBehindHead, gesture: .hideFace, line: "Hehe… hide and seek! You count first.", cheer: "Peekaboo!"),
            StoryStep(spot: .shoulder(.right), gesture: .fist, line: "You found me?! Catch me, quick!", cheer: "Caught!"),
            StoryStep(spot: .inFrontOfFace, gesture: .eyebrowRaise, line: "Missed! I'm right here. BOO! Scared?", cheer: "BOO!"),
        ],
        finale: "Fine, you win. Seen a little witch whose broom can't turn?"
    )

    static let witch = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .point, line: "Wheee! My broom can't steer! Which way?", cheer: "Whoosh!"),
            StoryStep(spot: .palm, gesture: .mouthOpen, line: "Phew! Now shout the spell with me!", cheer: "Abracadabra!"),
            StoryStep(spot: .besideHead(.right), gesture: .thumbsUp, line: "Almost! Every spell needs your approval.", cheer: "Poof!"),
        ],
        finale: "It worked! The tea is… slightly colder. A polite guest is knocking…"
    )

    static let reaper = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .nod, line: "Good evening. Forgive the intrusion. Shall we greet?", cheer: "Splendid."),
            StoryStep(spot: .shoulder(.left), gesture: .holdStill, line: "Your name is on my list… I must take your measurements.", cheer: "Thank you."),
            StoryStep(spot: .aboveHead, gesture: .point, line: "Ah, wrong list. It's for lawn trimming. Which grass?", cheer: "Snip snip."),
        ],
        finale: "My apologies. A pirate keeps asking for the nearest bathtub…"
    )

    static let captain = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .mouthOpen, line: "ARRR! Land ho! Shout with me, matey!", cheer: "ARRR!"),
            StoryStep(spot: .shoulder(.right), gesture: .wink, line: "I'm your parrot now! Know the pirate signal?", cheer: "Squawk!"),
            StoryStep(spot: .palm, gesture: .fist, line: "The treasure map was in your hand all along! Hold tight!", cheer: "Treasure!"),
        ],
        finale: "The real treasure was the crew. Hey… hear coins clinking?"
    )

    static let pixel = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .pinch, line: "INSERT COIN TO CONTINUE.", cheer: "COIN!"),
            StoryStep(spot: .aboveHead, gesture: .thumbsUp, line: "PLAYER 1 READY?", cheer: "START!"),
            StoryStep(spot: .shoulder(.left), gesture: .punch, line: "BOSS FIGHT!", cheer: "K.O.!"),
        ],
        finale: "YOU WIN! CONTINUE? Mister Q waits at level 1."
    )
}
