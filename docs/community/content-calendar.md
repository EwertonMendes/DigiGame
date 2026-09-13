# 90-day content calendar and post kit

The calendar assumes 3–5 hours per week, one bilingual X account, and no active public build distribution before the vertical-slice gate. Dates are intentionally relative so the cycle can start after the project identity and accounts are ready.

## Publishing pattern

- **Tuesday:** English X post.
- **Thursday:** Portuguese X post.
- **Once per week:** adapt the topic for one external community only.
- **Every second week:** add a more detailed update to the single With the Will thread.
- **Every week:** post a longer Discord note and spend at least one hour in genuine conversation.

## Twelve-week rotation

| Week | Core topic | State label | Primary asset | External destination | Specific question | CTA |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Why the active team is limited to three | Design decision | 10–15s formation clip | r/Digimon | Which role would be hardest for you to leave out? | Comment |
| 2 | Movement, range, and attack shapes | Implemented | Targeting GIF | r/IndieGaming + With the Will update | Is the affected area readable before confirmation? | Comment |
| 3 | Digivolve or degenerate and return to level 1 | Foundation implemented | Evolution chart capture | r/MonsterTamerWorld | Does the locked route explain its requirement clearly? | Comment |
| 4 | The current hub and its future growth | Early / planned growth | Hub before/target mockup | Brazilian community, after permission + With the Will | Which service should become recognizable first? | Comment |
| 5 | Why digivolution stays outside battle | Design decision | DigiLab-to-battle cut | r/Digimon | Does separating preparation from combat make the tactical layer clearer? | Comment |
| 6 | First Link-system example | Planned prototype | Short diagram or prototype clip | r/IndieGaming + With the Will | Which positioning cue would help you anticipate the Link? | Comment |
| 7 | Terrain and displacement | Implemented / experimental | Push/pull GIF | r/MonsterTamerWorld | Did you predict the final tile before the move resolved? | Comment |
| 8 | Browser play and mobile interface | Implemented foundation | Desktop/mobile comparison | Brazilian community + With the Will | Which information is hardest to read on the phone screen? | Comment |
| 9 | Tactical map before and after | Implemented iteration | Split-screen image | r/Digimon | Which route or danger do you notice first? | Comment |
| 10 | A change caused by feedback | Implemented change | Before/after clip | r/IndieGaming + With the Will | Does the new version solve the original confusion? | Discord only if open |
| 11 | Narrative premise: absolute order versus change | Planned narrative | Text motion card + hub footage | r/MonsterTamerWorld | Which side sounds convincing before either becomes extreme? | Comment |
| 12 | Solo developer story and 90-day recap | Development story | Montage | Brazilian community + With the Will | Which system should get the next deep dive? | Follow or Discord |

If the vertical slice is not ready at week 12, repeat the structure with new concrete problems and iterations; do not open the build to satisfy the calendar.

## Message formula

1. Show a visual hook or meaningful decision.
2. Explain one change or problem.
3. State how it affects the player.
4. Label it implemented, experimental, or planned.
5. Ask one concrete question.
6. Use one CTA only: comment, join Discord, or play.

Avoid “Would you play this?” and “What do you think?”. Ask about something observable: readability, expectation, choice, or consequence.

## Foundation introduction

### Portuguese

> Estou criando sozinho um RPG tático isométrico de Digimon, gratuito e não oficial. A ideia é juntar a progressão ramificada dos Digimon Story de DS com batalhas em grade para equipes de até três Digimon, onde posicionamento e sinergia realmente importam. O protótipo já possui hub, combate, bases de progressão e uma build Web, mas ainda estou preparando a primeira vertical slice para testes externos.

### English

> I'm solo-developing an unofficial, non-commercial Digimon isometric tactical RPG. It combines the branching progression I love from the Nintendo DS Digimon Story games with grid battles for teams of up to three Digimon, where positioning and team synergy matter. The prototype already has a hub, combat, progression foundations, and a Web build, but I'm still preparing the first external-playtest vertical slice.

## Three ready-to-capture post pairs

Replace bracketed evidence with the actual clip and confirm the state label against the current build before publishing.

### Post 1 — teams of three

**English**

> Why only three Digimon in the active team? With a small squad, every position, weakness, and teammate interaction has to earn its place. It also keeps the tactical grid readable on desktop and mobile. **State: implemented team-size rule; Link interactions are planned.** [Attach formation clip.] Which role would be hardest for you to leave out: defender, support, or damage? #DigimonFanGame #IndieGame

**Português**

> Por que apenas três Digimon na equipe ativa? Com um grupo pequeno, cada posição, fraqueza e interação entre aliados precisa importar. Isso também mantém a grade tática legível no computador e no celular. **Estado: limite da equipe implementado; interações Link planejadas.** [Anexar vídeo da formação.] Qual papel seria mais difícil deixar de fora: defesa, suporte ou dano? #DigimonFanGame #IndieGame

### Post 2 — attack readability

**English**

> An attack should be understandable before you commit to it. This prototype view separates movement tiles, valid targets, and the affected pattern so the decision happens before the animation. **State: implemented and still being refined.** [Attach targeting GIF.] Can you tell which enemies will be hit before the confirmation? #Digimon #GodotEngine

**Português**

> Um ataque precisa ser entendido antes da confirmação. Esta versão separa casas de movimento, alvos válidos e a área afetada para que a decisão aconteça antes da animação. **Estado: implementado e ainda em refinamento.** [Anexar GIF da mira.] Dá para saber quais inimigos serão atingidos antes de confirmar? #Digimon #GodotEngine

### Post 3 — evolution and degeneration

**English**

> In Digi Game, degeneration is not just an undo button. Returning to level 1 is intended to open a different growth route and make long-term team planning matter. Evolution happens in the DigiLab, outside combat. **State: progression foundation implemented; balance and presentation are experimental.** [Attach evolution-chart capture.] Does the locked route make its requirement clear? #DigimonFanGame #IndieGame

**Português**

> No Digi Game, degenerar não é apenas desfazer uma evolução. Voltar ao nível 1 deve abrir outra rota de crescimento e tornar o planejamento da equipe importante. A evolução acontece no DigiLab, fora do combate. **Estado: base da progressão implementada; balanceamento e apresentação experimentais.** [Anexar captura da árvore.] A rota bloqueada explica claramente o requisito? #DigimonFanGame #IndieGame

## Community adaptations

- **Reddit:** use a descriptive title, upload the visual natively, provide 2–4 paragraphs of context, disclose that you are the solo developer, and end with the specific question. Do not lead with Discord or repeat the same copy across subreddits.
- **With the Will:** keep one thread. Add build/date, what changed, why, current limitations, one visual, and what kind of feedback is useful.
- **Discord:** give more detail than the public post, link to the relevant design decision, and return later with what changed.
- **Brazilian groups:** participate first and obtain moderator permission. Share only major milestones or test invitations, approximately monthly.

## Feedback outcome post

Use this structure after every test round:

> **You said:** [the repeated player signal]  
> **I observed:** [completion data, reproduction, or behavior]  
> **Changed:** [specific change and target build]  
> **Not changing yet:** [reason, tradeoff, or evidence still needed]
