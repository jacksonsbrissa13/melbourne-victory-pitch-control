# Third-party notices

I release my original project code and documentation under the root [MIT licence](LICENSE). This grant covers only rights I can grant. Upstream software, source data, pretrained weights and broadcast material retain their own terms. These notices record attribution and licence information; they do not claim that every downloaded dependency or model weight is cleared for commercial use.

## Data and tracking software

### SkillCorner Open Data

- Source: [SkillCorner/opendata](https://github.com/SkillCorner/opendata).
- Upstream licence: MIT; [original licence](https://github.com/SkillCorner/opendata/blob/master/LICENSE).
- Preserved text: [SkillCorner-MIT.txt](licences/SkillCorner-MIT.txt), including its copyright notice.
- Role: match metadata, player and ball tracking, dynamic events, phases of play and field-of-view projections.

I download the raw dataset from its upstream repository rather than bundle it here. My analyses, calibration files and pitch-only figure use or refer to that data. The upstream licence and SkillCorner attribution apply to any upstream material reused; my licence does not replace them. I credit SkillCorner in the README and video legend.

### McByte++

- Source: [tstanczyk95/McBytePlusPlus](https://github.com/tstanczyk95/McBytePlusPlus).
- Upstream licence: Apache License 2.0; [original licence](https://github.com/tstanczyk95/McBytePlusPlus/blob/main/LICENSE).
- Preserved text: [McBytePlusPlus-Apache-2.0.txt](licences/McBytePlusPlus-Apache-2.0.txt).
- Authors credited upstream: Tomasz Stanczyk, Seongro Yoon and Francois Bremond.
- Role: GPU video tracking through my custom Colab notebook. The original run used revision `be1bbc03f18e33e93e0a359bbcbfdfc4dc4ab6b9`.

My notebook clones the upstream repository and installs its dependencies. It applies local compatibility adjustments to GUI waits, BF16 autocast and CPU video storage, described in its compatibility cell. I do not bundle the full McByte++ source tree or pretrained weights in this repository. If modified upstream software is redistributed, retain the applicable copyright and attribution notices, supply its licence, identify changes and preserve any applicable upstream NOTICE content as required by Apache 2.0. The root MIT licence does not replace Apache 2.0 or the terms of McByte++ submodules and downloaded weights.

## Methodological and visual references

I wrote my R control model and renderer for this project. The following projects informed the approach; they are not installed dependencies or bundled source trees. I preserve available licence texts for transparency and attribution, without claiming ownership of their code.

| Project | Contribution to this project | Upstream licence / preserved notice |
|---|---|---|
| [Friends of Tracking / LaurieOnTracking](https://github.com/Friends-of-Tracking-Data-FoTD/LaurieOnTracking) | Arrival-time pitch-control methods: reaction, velocity, ball travel and competing team control. | [MIT](licences/LaurieOnTracking-MIT.txt); copyright notice retained. |
| [thecomeonman / CodaBonito](https://github.com/thecomeonman/CodaBonito) | R pitch-control examples and football plotting methods. | [MIT](licences/CodaBonito-MIT.txt); copyright notice retained. |
| [mkh1991 / pitch-control](https://github.com/mkh1991/pitch-control) | Modular model and calculation design. | [MIT](licences/pitch-control-MIT.txt); copyright notice retained. |
| [Vsll92 / football-pitch-control](https://github.com/Vsll92/football-pitch-control) | Visual inspiration for team-colour surfaces and contested regions. | No explicit licence identified in the reviewed repository. I have not copied or bundled its code or assets; this link is an inspiration credit. |

## Broadcast material

The source clip comes from A-Leagues highlights titled *Melbourne Victory v Auckland FC – Shark Highlights | Isuzu UTE A-League 2024-25 | Semi-Final Leg One*, published 17 May 2025. Paramount+ branding is retained in the sample frame.

`docs/assets/annotated-video-sample.png` combines a broadcast frame with my annotations. Its broadcast content is excluded from my MIT grant. Credit does not establish redistribution permission; I have not verified a licence permitting public reuse of that content. No source or annotated MP4 is bundled here. This repository grants no rights to third-party footage, logos or branding.

## Dependencies and pretrained weights

The R and Python packages, McByte++ submodules and pretrained weights downloaded during setup retain their respective licences. They are not relicensed by this repository. Check the terms attached to the exact versions and weights you use, particularly before redistribution or commercial deployment.

Upstream licence texts in `licences/` were retrieved from the linked official repositories on 1 October 2026 and preserved unchanged. They describe those sources at review time; future upstream changes may require another review.
