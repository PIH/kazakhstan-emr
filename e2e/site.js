// What the tests expect of the Kazakhstan site
const path = require('path');
const host = new URL(process.env.BASE_URL || 'https://localhost').hostname;

module.exports = {
  // The test patient's uuids on the system under test (written by global-setup.js)
  patientFile: path.join(__dirname, `.patient-${host}.json`),
  user: { username: 'e2e-test', password: 'E2eTest123' },
  location: { name: 'KZ', uuid: '371df356-3f5a-11e5-b380-0050568236ae' },
  identifierType: '8967f9d3-3a91-11e5-b380-0050568236ae', // Patient Identifier, format KZ[MS]-ddd-ddddd
  patient: { identifier: 'KZS-999-99999', name: { givenName: 'Spike', familyName: 'E2etest', preferred: true } },
  // The test patient's TB enrollment, which the Patient Monitoring Tool and endTB save hooks need
  program: { uuid: '3ad05b62-40fa-4d2f-8e8f-4377c0e146f5', name: 'Second-line TB treatment register',
             dateEnrolled: '2026-09-01', registrationNumber: 'E2E-TEST-0001' },
  registrationNumberType: '15799645-c5ae-11e5-905b-005056826881',
  visitType: '35a54a04-78e5-438f-b697-aa4340d5a846', // General
  homeTiles: ['Registration', 'Patient Records', 'Admin', 'Reports', 'Exports', 'Data Quality'],
  dashboardTabs: ['General', 'stemTB', 'Mental Health', 'endTB', 'Documents', 'Monitoring (T)', 'Monitoring (D)'],
  obsForms: [
    'STEM-TB Baseline Assessment', 'STEM-TB Monthly Clinical Examination Log', 'STEM-TB Chest X-Ray',
    'STEM-TB Hospitalizations', 'STEM-TB Lab Results Log', 'STEM-TB Monthly Treatment Completeness',
    'STEM-TB Adverse Events', 'Serious Adverse Events', 'STEM-TB End of Treatment',
    'STEM-TB Quarterly Post Treatment', 'STEM-TB Final Post-Treatment Outcome',
    'Mental Health Baseline', 'Mental Health Visit', 'Mental Health Common Elements Treatment Approach Baseline Visit',
    'Mental Health Common Elements Treatment Approach Follow-up Visit', 'Mental Health Outcome of Patient',
  ],
};
