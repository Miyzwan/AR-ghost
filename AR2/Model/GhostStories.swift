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
            StoryStep(spot: .aboveHead, gesture: .smile, line: "Sniff sniff… your aura smells a little sour today. Can you smile for me?", cheer: "Yum!"),
            StoryStep(spot: .shoulder(.right), gesture: .nod, line: "Ooh, that smile tastes sweet! Will you be my friend? Nod if yes.", cheer: "Friends!"),
            StoryStep(spot: .palm, gesture: .openPalm, line: "Friends share secrets. Open your palm and I'll read your fortune line…", cheer: "Ooh, fancy!"),
        ],
        finale: "Your fortune says… you're not sad at all! Uh-oh. Someone is furious that I turned nice…"
    )

    static let trueForm = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .shakeHead, line: "WHO MADE MISTER Q SOFT?! Was it YOU?!", cheer: "Hmph!"),
            StoryStep(spot: .aboveHead, gesture: .punch, line: "Liar! Prove you're brave. Punch me, if you can!", cheer: "OOF!"),
            StoryStep(spot: .shoulder(.left), gesture: .cheekPuff, line: "…Not bad, human. Now puff your cheeks and blow my anger away.", cheer: "Phew…"),
        ],
        finale: "Hmph. I feel… calm. In the next grave over, there's a ghost who badly wants a hug."
    )

    static let boo = GhostStory(
        steps: [
            StoryStep(spot: .chest, gesture: .touchGhost, line: "I'm clinging to you! Hug me, touch me with your hand!", cheer: "Hug!"),
            StoryStep(spot: .besideHead(.left), gesture: .tiltHead, line: "Your hand went right through me again… Tilt your head closer, I want to whisper.", cheer: "Psst!"),
            StoryStep(spot: .inFrontOfFace, gesture: .kiss, line: "Nobody has ever hugged me back. Maybe a kiss from afar works?", cheer: "Mwah!"),
        ],
        finale: "It worked! My first hug ever. My friend Wavy is still waving at people who never wave back…"
    )

    static let wavy = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .wave, line: "Hello? HELLO? Can anybody see me? Wave if you can!", cheer: "Hi hi!"),
            StoryStep(spot: .palm, gesture: .peace, line: "YOU CAN SEE ME! Quick, let's take a picture. Peace sign!", cheer: "Cheese!"),
            StoryStep(spot: .shoulder(.right), gesture: .wink, line: "Only people who can see ghosts know the secret signal. Wink at me!", cheer: "Hehe!"),
        ],
        finale: "Now I have a friend! Psst… something furry just fell asleep on top of your head…"
    )

    static let mochi = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .holdStill, line: "Zzz… purrr… zzz… (Shh, don't wake her up.)", cheer: "Purr…"),
            StoryStep(spot: .palm, gesture: .pinch, line: "*yawn* …Is that tuna I smell? Pinch a little bit for me.", cheer: "Tuna!"),
            StoryStep(spot: .shoulder(.left), gesture: .tongueOut, line: "Delicious! Now let's groom together. Stick out your tongue!", cheer: "Mlem!"),
        ],
        finale: "Purrfect human. My twin sister Nori hides in the dark. Careful, she loves to play tricks…"
    )

    static let nori = GhostStory(
        steps: [
            StoryStep(spot: .peekBehindHead, gesture: .hideFace, line: "Hehe… let's play hide and seek. Cover your face and count!", cheer: "Peekaboo!"),
            StoryStep(spot: .shoulder(.right), gesture: .fist, line: "You found me?! Catch me, quick, grab me!", cheer: "Caught!"),
            StoryStep(spot: .inFrontOfFace, gesture: .eyebrowRaise, line: "Missed! I'm right in front of you. BOO! Did I scare you?", cheer: "BOO!"),
        ],
        finale: "Fine, you win. Have you seen a little witch flying in circles? Her broom can't turn…"
    )

    static let witch = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .point, line: "Wheee! My broom can't steer! Point the way, quick!", cheer: "Whoosh!"),
            StoryStep(spot: .palm, gesture: .mouthOpen, line: "Phew, thank you! Help me cast a spell. Open your mouth wide: ABRACADABRA!", cheer: "Abracadabra!"),
            StoryStep(spot: .besideHead(.right), gesture: .thumbsUp, line: "Almost there! Every spell needs a thumbs up to work.", cheer: "Poof!"),
        ],
        finale: "It worked! The tea became… slightly colder tea. Oh, a very polite guest is knocking…"
    )

    static let reaper = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .nod, line: "Good evening. Forgive the intrusion. Kindly return my greeting with a nod.", cheer: "Splendid."),
            StoryStep(spot: .shoulder(.left), gesture: .holdStill, line: "Your name is on my list… Please stay very still while I take measurements.", cheer: "Thank you."),
            StoryStep(spot: .aboveHead, gesture: .point, line: "Ah, my mistake. This is my grass-trimming list. Point to the grass that needs trimming.", cheer: "Snip snip."),
        ],
        finale: "My sincere apologies. By the way, a pirate keeps asking where the nearest bathtub is…"
    )

    static let captain = GhostStory(
        steps: [
            StoryStep(spot: .aboveHead, gesture: .mouthOpen, line: "ARRR! Land ho! Shout \"Arrr!\" with me, matey!", cheer: "ARRR!"),
            StoryStep(spot: .shoulder(.right), gesture: .wink, line: "Every captain needs a parrot, so I'll be yours! A true pirate winks with one eye.", cheer: "Squawk!"),
            StoryStep(spot: .palm, gesture: .fist, line: "The treasure map… it was in your hand all along! Hold it tight!", cheer: "Treasure!"),
        ],
        finale: "The real treasure was the crew we made along the way. Hey… do you hear coins clinking?"
    )

    static let pixel = GhostStory(
        steps: [
            StoryStep(spot: .inFrontOfFace, gesture: .pinch, line: "INSERT COIN. Pinch a coin to continue.", cheer: "COIN!"),
            StoryStep(spot: .aboveHead, gesture: .thumbsUp, line: "PLAYER 1 READY? Thumbs up to start!", cheer: "START!"),
            StoryStep(spot: .shoulder(.left), gesture: .punch, line: "BOSS FIGHT! Punch the boss!", cheer: "K.O.!"),
        ],
        finale: "YOU WIN! GAME OVER… CONTINUE? Mister Q is waiting back at level 1."
    )
}
