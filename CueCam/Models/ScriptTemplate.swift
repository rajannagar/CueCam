import Foundation

/// Starter scripts users can begin from. Real, usable copy with [brackets] to fill in.
struct ScriptTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let blurb: String
    let body: String

    static let all: [ScriptTemplate] = [
        ScriptTemplate(
            title: "YouTube Intro",
            icon: "play.rectangle.fill",
            blurb: "Hook, promise, subscribe nudge",
            body: """
            What's up everyone, welcome back to the channel.

            If you're new here, I make videos about [your topic], so hit subscribe so you don't miss anything.

            In today's video, I'm going to show you [the one big thing they'll learn]. By the end, you'll be able to [clear payoff].

            Let's get into it.
            """
        ),
        ScriptTemplate(
            title: "TikTok / Reels Hook",
            icon: "bolt.fill",
            blurb: "Stop-the-scroll opener",
            body: """
            Stop scrolling. If you [audience], you need to hear this.

            Most people get [common mistake] completely wrong. Here's what to do instead.

            First, [tip one]. Then, [tip two]. And the one nobody talks about: [tip three].

            Follow for more, and save this so you don't forget.
            """
        ),
        ScriptTemplate(
            title: "Best Man Speech",
            icon: "party.popper.fill",
            blurb: "Warm, funny, heartfelt",
            body: """
            For those who don't know me, I'm [name], and I've had the honor of being [groom]'s best friend for [number] years.

            When I first met [groom], I knew right away that [short, funny story].

            But here's what really matters. The day he met [partner], everything changed. He became [how they changed for the better].

            So please, raise your glasses. To the happy couple. May your love grow stronger every single day. Cheers.
            """
        ),
        ScriptTemplate(
            title: "Wedding Vows",
            icon: "heart.fill",
            blurb: "Personal promises",
            body: """
            [Partner], from the moment I met you, I knew my life would never be the same.

            I promise to stand beside you in every season: to laugh with you, to listen to you, and to choose you, every single day.

            I promise to be your partner, your safe place, and your biggest fan.

            Today, and for all the days after, I give you my heart. I love you.
            """
        ),
        ScriptTemplate(
            title: "Sales Pitch",
            icon: "chart.line.uptrend.xyaxis",
            blurb: "Problem, solution, ask",
            body: """
            Thanks for taking the time today. I'll keep this quick.

            Right now, [prospect] is dealing with [the painful problem]. It's costing you [time/money/effort].

            That's exactly what we solve. [Product] helps you [key outcome] without [the usual downside].

            Teams like [example] saw [specific result]. I'd love to set you up with the same. Can we start with [clear next step]?
            """
        ),
        ScriptTemplate(
            title: "Product Demo",
            icon: "shippingbox.fill",
            blurb: "Show, don't tell",
            body: """
            Let me show you how this works in under a minute.

            Say you want to [common task]. Normally that takes [old way]. Watch this.

            [Step one]. [Step two]. And just like that, done.

            That's the whole idea: [core benefit]. Want to try it yourself? Here's how to get started.
            """
        )
    ]
}
