// Creates the fake test patient through REST if it doesn't exist, with a TB enrollment and an open visit, and
// saves the uuids for the tests.
const fs = require('fs');
const path = require('path');
const { request } = require('@playwright/test');
const site = require('./site');

module.exports = async (config) => {
  const baseURL = config.projects[0].use.baseURL;
  const api = await request.newContext({ baseURL, ignoreHTTPSErrors: true, httpCredentials: site.user });
  const rest = '/openmrs/ws/rest/v1';

  const found = await (await api.get(`${rest}/patient?identifier=${site.patient.identifier}`)).json();
  let uuid = found.results?.[0]?.uuid;
  if (!uuid) {
    const res = await api.post(`${rest}/patient`, { data: {
      person: { names: [site.patient.name], gender: 'M', birthdate: '1980-01-01' },
      identifiers: [{ identifier: site.patient.identifier, identifierType: site.identifierType,
                      location: site.location.uuid, preferred: true }],
    } });
    if (!res.ok()) throw new Error(`Creating the test patient failed: ${res.status()} ${await res.text()}`);
    uuid = (await res.json()).uuid;
  }
  const enrollments = await (await api.get(`${rest}/programenrollment?patient=${uuid}&v=custom:(uuid,program:(uuid))`)).json();
  let enrollment = enrollments.results.find((e) => e.program.uuid === site.program.uuid)?.uuid;
  if (!enrollment) {
    const res = await api.post(`${rest}/bahmniprogramenrollment`, { data: {
      patient: uuid, program: site.program.uuid, dateEnrolled: `${site.program.dateEnrolled}T00:00:00.000+0500`,
      attributes: [{ attributeType: site.registrationNumberType, value: site.program.registrationNumber }],
    } });
    if (!res.ok()) throw new Error(`Enrolling the test patient failed: ${res.status()} ${await res.text()}`);
    enrollment = (await res.json()).uuid;
  }

  const visits = await (await api.get(`${rest}/visit?patient=${uuid}&includeInactive=false`)).json();
  if (!visits.results.length) {
    const res = await api.post(`${rest}/visit`, { data: { patient: uuid, visitType: site.visitType, location: site.location.uuid } });
    if (!res.ok()) throw new Error(`Starting a visit failed: ${res.status()} ${await res.text()}`);
  }

  fs.writeFileSync(site.patientFile, JSON.stringify({ uuid, enrollment }));
  await api.dispose();
};
