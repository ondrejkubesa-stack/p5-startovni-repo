// Test akceptačního kritéria A1 (docs/spec.md) · šablona P5.1 · ověřeno k 2026-10-12 (@playwright/test, verze podle package.json)
// Píše se PŘED kódem aplikace a musí nejdřív spadnout (T1). Pak se už nemění, mění se aplikace.
// Popisky polí a tlačítek jsou ze spec, oddíl 5. Když spec změníš, změň vědomě i test (a napiš proč do PR).
import { test, expect } from '@playwright/test';

test('nová poptávka se objeví v seznamu se stavem Nová', async ({ page }) => {
  const popis = `Testovací skříň do předsíně ${Date.now()}`; // unikátní text, aby test nenašel starý řádek

  await page.goto('/');
  await page.getByLabel('Popis poptávky').fill(popis);
  await page.getByLabel('Kanál').selectOption('web');
  await page.getByRole('button', { name: 'Uložit poptávku' }).click();

  const radek = page.getByRole('row').filter({ hasText: popis });
  await expect(radek).toBeVisible();
  await expect(radek).toContainText('Nová');
});
