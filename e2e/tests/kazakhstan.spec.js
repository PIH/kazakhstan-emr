const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');
const site = require('../site');

const testData = () => JSON.parse(fs.readFileSync(site.patientFile));
const patient = () => testData().uuid;
// Dashboard URL parameters for the test patient's TB enrollment
const programParams = () =>
  `dateEnrolled=${site.program.dateEnrolled}&programUuid=${site.program.uuid}&enrollment=${testData().enrollment}`;

// Fails the test on uncaught JS errors in the page
function trackPageErrors(page) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  return errors;
}

const auth = { Authorization: 'Basic ' + Buffer.from(`${site.user.username}:${site.user.password}`).toString('base64') };

// All of a REST search's results, page by page
async function restResults(request, url) {
  const limit = 100;
  const results = [];
  for (let startIndex = 0; ; startIndex += limit) {
    const page = (await (await request.get(`${url}&limit=${limit}&startIndex=${startIndex}`, { headers: auth })).json()).results;
    results.push(...page);
    if (page.length < limit) return results;
  }
}

// Values of the test patient's obs for a concept, by its display name
async function obsValues(request, concept) {
  const obs = await restResults(request, `/openmrs/ws/rest/v1/obs?patient=${patient()}&v=custom:(value,concept:(display))`);
  return obs.filter((o) => o.concept.display === concept).map((o) => o.value);
}

// Saves the open form; fails unless the encounter is saved
async function save(page) {
  const saved = page.waitForResponse((r) => r.request().method() === 'POST' && /bahmniencounter/.test(r.url()));
  await page.getByRole('button', { name: 'Save' }).first().click();
  expect((await saved).status()).toBe(200);
}

async function login(page, locale) {
  await page.goto('/bahmni/home/');
  // The login page can ask for its locales before its session exists (more often just after startup),
  // leaving the list empty until a reload
  for (let attempt = 0; locale && attempt < 3; attempt++) {
    const listed = await page.locator(`#locale option[value="string:${locale}"]`).waitFor({ state: 'attached', timeout: 15_000 })
      .then(() => true, () => false);
    if (listed) break;
    await page.reload();
  }
  if (locale) await page.locator('#locale').selectOption(locale);
  await page.fill('#username', site.user.username);
  await page.fill('#password', site.user.password);
  // Bahmni 0.89 asks for the location on the login form; current Bahmni on a page after it
  const location = page.locator('#location');
  if (await location.isVisible()) await location.selectOption({ label: site.location.name });
  await page.locator('button.confirm').first().click();
  await page.waitForURL(/loginLocation|dashboard/);
  if (page.url().includes('loginLocation')) {
    await page.locator('#location').selectOption({ label: site.location.name });
    await page.locator('button.confirm').click();
  }
  await page.waitForURL(/#\/dashboard/);
}

test('login shows the home tiles', async ({ page }) => {
  const errors = trackPageErrors(page);
  await login(page);
  for (const tile of site.homeTiles) {
    await expect(page.getByText(tile, { exact: true }).filter({ visible: true }).first()).toBeVisible();
  }
  expect(errors).toEqual([]);
});

test('patient dashboard shows every tab', async ({ page }) => {
  const errors = trackPageErrors(page);
  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard?${programParams()}`);
  await expect(page.getByText(site.program.registrationNumber).filter({ visible: true }).first())
    .toBeVisible({ timeout: 60_000 });
  for (const tab of site.dashboardTabs) {
    await page.getByText(tab, { exact: true }).filter({ visible: true }).first().click();
    await expect(page.locator('.error-message, .message-container.error')).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});

test('observation forms are listed and open', async ({ page }) => {
  const errors = trackPageErrors(page);
  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard/concept-set-group/observations`);
  const add = page.getByText('Add New Obs Form').first();
  await add.click({ timeout: 60_000 });
  for (const form of site.obsForms) {
    await expect(page.getByRole('button', { name: form, exact: true })).toBeVisible();
  }
  // Open each form: it renders at least one field
  for (const form of site.obsForms) {
    await page.getByRole('button', { name: form, exact: true }).click();
    await expect(page.locator('.concept-set-group .leaf-observation-node, .concept-set-group input, .concept-set-group select').first())
      .toBeVisible({ timeout: 30_000 });
    await add.click();
  }
  expect(errors).toEqual([]);
});

test('saving Treatment Initiation shows the Patient Monitoring schedule', async ({ page, request }) => {
  const errors = trackPageErrors(page);
  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard/concept-set-group/observations?${programParams()}`);
  const add = page.getByText('Add New Obs Form').first();
  await add.click({ timeout: 60_000 });
  // The endTB module allows one per treatment (repeat runs)
  if ((await obsValues(request, 'TUBERCULOSIS DRUG TREATMENT START DATE')).length === 0) {
    await page.getByRole('button', { name: 'Treatment Initiation', exact: true }).click();
    const field = (label) => page.locator('.leaf-observation-node').filter({ hasText: label }).first();
    await field('Start treatment?').getByRole('button', { name: 'Yes', exact: true }).click();
    await field('Treatment start date').locator('input[type=date]').fill(site.program.dateEnrolled);
    await save(page);
  }

  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard?${programParams()}`);
  await page.getByText('Monitoring (T)', { exact: true }).filter({ visible: true }).first().click();
  await expect(page.getByText(site.program.registrationNumber).filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  await expect(page.getByText('Start date missing')).toHaveCount(0);
  // The schedule grid: months from treatment start, and the milestones from patientMonitoringConf.json
  await expect(page.getByText('M1', { exact: true }).filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  await expect(page.getByText('Vital Signs', { exact: true }).filter({ visible: true }).first()).toBeVisible();
  expect(errors).toEqual([]);
});

test('the obs calculator adds BMI to a saved Baseline form', async ({ page, request }) => {
  const errors = trackPageErrors(page);

  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard/concept-set-group/observations?${programParams()}`);
  await page.getByText('Add New Obs Form').first().click({ timeout: 60_000 });
  // The endTB module allows one per treatment (repeat runs)
  if ((await obsValues(request, 'Baseline, Date of baseline')).length === 0) {
    await page.getByRole('button', { name: 'Baseline', exact: true }).click();
    const field = (label) => page.locator('.leaf-observation-node').filter({ hasText: label }).first();
    await field('Date of baseline assessment').locator('input[type=date]').fill(site.program.dateEnrolled);
    await field('Weight (').locator('input').fill('60');
    await field('Height (').locator('input').fill('170');
    await save(page);
  }
  // 60 kg / 1.70 m squared
  expect(await obsValues(request, 'Body mass index')).toContainEqual(20.76);
  expect(errors).toEqual([]);
});

test('saving a Mental Health Visit stores its observations', async ({ page, request }) => {
  const errors = trackPageErrors(page);
  const phq9 = 'MH, Patient Health Questionnaire Nine Item score';

  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard/concept-set-group/observations`);
  await page.getByText('Add New Obs Form').first().click({ timeout: 60_000 });
  // Once saved in the open visit, the form is no longer offered (repeat runs)
  if ((await obsValues(request, phq9)).length === 0) {
    await page.getByRole('button', { name: 'Mental Health Visit', exact: true }).click();
    const field = (label) => page.locator('.leaf-observation-node').filter({ hasText: label }).first();
    await field('Visit Date').locator('input[type=date]').fill(site.program.dateEnrolled);
    await field('Mental health intervention').getByRole('button', { name: 'Psychosocial counseling', exact: true }).click();
    await field('PHQ-9').locator('input[type=number]').fill('12');
    await field('Return visit date').locator('input[type=date]').fill('2026-10-01');
    await save(page);
  }
  expect(await obsValues(request, phq9)).toContainEqual(12);

  // The Mental Health tab's Visit table shows the return visit date entered, not the visit date (BAH-5266)
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard`);
  await page.getByText('Mental Health', { exact: true }).filter({ visible: true }).first().click({ timeout: 60_000 });
  const visits = page.locator('table').filter({ hasText: 'Return visit date' }).first();
  // 0.89 writes the year as 26, current Bahmni as 2026
  await expect(visits).toContainText(/01 Oct (20)?26/, { timeout: 30_000 });
  expect(errors).toEqual([]);
});

test('ordering a TB drug shows it on the Drug-O-Gram', async ({ page, request }) => {
  const errors = trackPageErrors(page);
  const orders = async () => (await restResults(request, `/openmrs/ws/rest/v1/order?patient=${patient()}&t=drugorder&v=custom:(drug:(display))`))
    .map((o) => o.drug.display);

  await login(page);
  if (!(await orders()).includes('Isoniazid (H)')) {
    await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard/treatment?${programParams()}&tabConfigName=tbTabConfig`);
    await page.locator('select[ng-model="treatment.selectedItem"]').selectOption({ label: 'Isoniazid (H)' }, { timeout: 60_000 });
    await page.locator('#uniform-dose').fill('300');
    await page.locator('#uniform-dose-unit').selectOption({ label: 'mg' });
    await page.locator('#frequency').selectOption({ label: '7 days per week' });
    await page.locator('#route').selectOption({ label: 'Oral (PO)' });
    await page.locator('#start-date').fill(new Date().toISOString().slice(0, 10));
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await save(page);
  }
  expect(await orders()).toContain('Isoniazid (H)');

  // The chart's columns are the drugs' abbreviations, with the dose
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard?${programParams()}`);
  await page.getByText('stemTB', { exact: true }).filter({ visible: true }).first().click({ timeout: 60_000 });
  await expect(page.getByText('Drug Regimen', { exact: true }).filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  await expect(page.getByText('H', { exact: true }).filter({ visible: true }).first()).toBeVisible();
  await expect(page.getByText('300', { exact: true }).filter({ visible: true }).first()).toBeVisible();
  expect(errors).toEqual([]);
});

test('the Russian locale translates the UI', async ({ page }) => {
  const errors = trackPageErrors(page);
  await login(page, 'ru');
  // Registration, Reports, Data Quality (home/locale_ru.json)
  for (const tile of ['Регистрация', 'Отчеты', 'Качество данных']) {
    await expect(page.getByText(tile, { exact: true }).filter({ visible: true }).first()).toBeVisible();
  }
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard?${programParams()}`);
  // The General tab, and the Drug-O-Gram title on the stemTB tab (clinical/locale_ru.json)
  await expect(page.getByText('Общая', { exact: true }).filter({ visible: true }).first()).toBeVisible({ timeout: 60_000 });
  await page.getByText('stemTB', { exact: true }).filter({ visible: true }).first().click();
  await expect(page.getByText('Режим Лечения', { exact: true }).filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  expect(errors).toEqual([]);
});

test('the Reports app lists every report', async ({ page }) => {
  const errors = trackPageErrors(page);
  // Current Bahmni hides reports whose requiredPrivilege the user lacks, including ones with none set
  const reports = JSON.parse(fs.readFileSync(path.join(__dirname, '../../config/openmrs/apps/reports/reports.json')));
  await login(page);
  await page.goto('/bahmni/reports/#/dashboard');
  for (const report of Object.values(reports)) {
    await expect(page.getByText(report.name, { exact: true }).filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  }
  expect(errors).toEqual([]);
});

test('a report runs', async ({ page }) => {
  // Through the logged-in browser, so the reports app gets the session from its cookie. Only the test patient's
  // visit date, to read as little real data as possible, and only the file type is checked, never its contents.
  await login(page);
  const query = new URLSearchParams({
    name: 'Kazakhstan Mental Health Visits (non-CETA) (Excel)', startDate: site.program.dateEnrolled,
    endDate: site.program.dateEnrolled, responseType: 'application/vnd.ms-excel', paperSize: 'A3', appName: 'reports',
  });
  const response = await page.request.get(`/bahmnireports/report?${query}`, { maxRedirects: 0, timeout: 300_000 });
  expect(response.status()).toBe(200);
  expect(response.headers()['content-type']).toContain('application/vnd.ms-excel');
  // An .xlsx file (a zip)
  expect((await response.body()).subarray(0, 2).toString()).toBe('PK');
});

test('new patient registration asks for the last name', async ({ page }) => {
  const errors = trackPageErrors(page);
  // Current Bahmni hides it unless registration config sets showLastName
  await login(page);
  await page.goto('/bahmni/registration/#/patient/new');
  const lastName = page.locator('#familyName');
  await expect(lastName).toBeVisible({ timeout: 60_000 });
  await expect(lastName).toHaveAttribute('required', /.*/);
  expect(errors).toEqual([]);
});

test('every dashboard tab loads without server errors', async ({ page }) => {
  const errors = trackPageErrors(page);
  const failed = [];
  // implementation_config is an optional overlay the UI always asks for; Kazakhstan has none
  const optional = /implementation_config|offline-language|%7B|diagnosisServiceConfig/;
  page.on('response', (r) => { if (r.status() >= 400 && !optional.test(r.url())) failed.push(`${r.status()} ${r.url()}`); });
  await login(page);
  await page.goto(`/bahmni/clinical/#/default/patient/${patient()}/dashboard?${programParams()}`);
  for (const tab of site.dashboardTabs) {
    await page.getByText(tab, { exact: true }).filter({ visible: true }).first().click();
    await page.waitForLoadState('networkidle');
  }
  expect(failed).toEqual([]);
  expect(errors).toEqual([]);
});
