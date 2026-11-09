# Spanish translation review

**Draft, not linguistically verified.** The Latin American Spanish translation
is a community contribution from [discussion #368](https://github.com/moss-apps/Flick/discussions/368).
The contributor reports using ChatGPT to assist with translation. Technical
checks and corrections do not replace native-speaker approval.

## Try it

1. Open Settings → Interface → Language and select **Español (Latinoamérica)**.
2. The language option marks the translation as a draft pending native-speaker
   review, just as Taglish retains its own draft notice.
3. **English** remains a recognizable escape option in every language.
4. With **System default** selected, Spanish device locales (including `es_MX`
   and `es_419`) use this same `es` resource. It is Latin American copy, not a
   separate regional translation for each Spanish-speaking country.

The language choice persists across restarts. Taglish's optional Baybayin labels
do not apply to Spanish.

## Review before treating it as approved

- [ ] Native speaker checks natural wording, consistency and Latin American usage.
- [ ] Check onboarding, library navigation, settings, player actions and help on
      an Android device, including narrow screens and enlarged text.
- [ ] Check count-dependent messages with zero, one and multiple items, especially
      identification, playlist sync and duplicate cleanup.
- [ ] Review audio terminology and warnings: bit-perfect bypass, DSP, DSD/DoP,
      fixed USB volume and 432/440 tuning must retain their technical meaning.
- [ ] Confirm library-removal and file-deletion warnings remain unambiguous.
- [ ] Confirm switching back to English and restoring the saved choice work on
      a device.

Keep the draft notice until native-speaker review is complete. Automated tests
cover resource parity, arguments, selected wording and language-switch behavior;
they do not approve the translation or replace device testing.
