# Discord setup

Create the server only after the working name and account ownership are confirmed. Start with the minimum structure below; add channels only when real usage demands them.

## Server structure

| Category | Channel | Purpose and suggested topic |
| --- | --- | --- |
| START | `start-here` | Read-only welcome, rules, language roles, project status, and disclaimer. |
| UPDATES | `announcements` | Read-only development updates with one clear state label: implemented, experimental, or planned. |
| UPDATES | `builds-and-tests` | Read-only build notes, known issues, test windows, and one current test link. Keep empty of public builds before the gate. |
| COMMUNITY | `geral-pt` | Conversas em português sobre o projeto e Digimon. |
| COMMUNITY | `general-en` | English conversation about the project and Digimon. |
| COMMUNITY | `general-es` | Conversación en español sobre el proyecto y Digimon. |
| PLAYTEST | `feedback` | Structured impressions and design feedback using the pinned template. Prefer a Forum channel when available. |
| PLAYTEST | `bugs` | Reproducible problems using the pinned bug template. Prefer a Forum channel with status tags. |

## Roles

- `Playtester`: access to closed-test posts and build links.
- `PT-BR`: Portuguese update and conversation role.
- `English`: English update and conversation role.
- `Español`: Spanish update and conversation role.

Do not give the language roles moderation permissions. Keep `Playtester` manually assigned during the first closed cohort. Use Discord's built-in onboarding or reaction roles only after the basic server flow is stable.

## Welcome copy

### English

Welcome to the Digi Game development community. This is an early, unofficial, non-commercial Digimon tactical RPG fan project made by one developer. Choose a language role, read the current project status, and join the conversation. The public playtest is not open yet; test invitations will appear in `builds-and-tests` when the vertical slice is ready.

### Português

Boas-vindas à comunidade de desenvolvimento do Digi Game. Este é um fan game tático de Digimon, não oficial, não comercial e ainda no começo, feito por uma pessoa. Escolha seu cargo de idioma, confira o estado atual do projeto e participe das conversas. O teste público ainda não está aberto; os convites aparecerão em `builds-and-tests` quando a vertical slice estiver pronta.

### Español

Te damos la bienvenida a la comunidad de desarrollo de Digi Game. Este es un proyecto de fans de Digimon, táctico, no oficial, no comercial y todavía en una fase temprana, creado por una sola persona. Elige tu rol de idioma, consulta el estado actual y participa en las conversaciones. La prueba pública aún no está abierta; las invitaciones aparecerán en `builds-and-tests` cuando la vertical slice esté lista.

## Rules

1. Treat other members with respect; harassment, hate speech, and personal attacks are not allowed.
2. Keep discussion in the channel's language and use the matching language channel.
3. Do not share leaked, pirated, or paid copyrighted material.
4. Do not impersonate staff or rights holders, and do not present this project as official.
5. Keep feedback specific and about the work, not the person. Disagreement is welcome; hostility is not.
6. Report bugs with build, device, steps, result, and expected result when possible.
7. Closed-test links and files stay inside the playtest group unless explicitly released.
8. No unsolicited advertising or direct-message promotion.

Pin the following disclaimer in `start-here` and include it in the server description where it fits:

> Digi Game is a non-commercial fan project. Digimon and all related characters and properties belong to their respective rights holders. This project is not affiliated with or endorsed by Bandai, Bandai Namco, Toei Animation, or other rights holders.

## Feedback forum tags

For `feedback`: `Controls`, `Combat`, `Evolution`, `Hub`, `Mobile`, `Clarity`, `Suggestion`, `Answered`.

For `bugs`: `New`, `Needs info`, `Reproduced`, `Fixed next build`, `Cannot reproduce`, plus `Desktop` and `Android`.

## First closed cohort

Invite 10–20 people manually. Give each test window one announcement, one build note, one known-issues list, and one deadline. Do not ping every role for routine discussion. Close the loop after each round with:

> You said → I observed → changed → not changing yet because…

