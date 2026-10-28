/** Public, deterministic catalogue payload. Never an authorization or playback API. */
export const PUBLIC_CATALOG_SCHEMA = 'OSA_CINEMA_PUBLIC_CATALOG_V1'
const origin = 'https://osgard.world'
const validCategories = new Set(['interactive', 'film', 'previz'])
const validStates = new Set(['interactive_public', 'owner_local', 'not_filmed'])
const validGates = new Set(['verified', 'pending', 'blocked'])
export function createPublicCinemaCatalog(works) {
  if (!Array.isArray(works) || works.length < 1 || works.length > 100) throw Error('Invalid editorial registry size')
  const used = new Set()
  const projects = works.map(work => {
    if (!work || typeof work !== 'object' || typeof work.id !== 'string' ||
        !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(work.id) || used.has(work.id) ||
        !validCategories.has(work.category) || !validStates.has(work.releaseState) ||
        typeof work.title !== 'string' || typeof work.english !== 'string' ||
        typeof work.description !== 'string' || typeof work.descriptionEn !== 'string' ||
        typeof work.status !== 'string' || typeof work.statusEn !== 'string' ||
        !/^(understand|decide|verify)\.webp$/.test(work.artwork) ||
        !Array.isArray(work.gates) || !work.gates.every(g => g && validGates.has(g.state))) {
      throw Error('Invalid or duplicate editorial project')
    }
    used.add(work.id)
    const isInteractive = work.releaseState === 'interactive_public' && work.href === '/osa-cinema'
    return {
      id: work.id,
      category: work.category,
      year: work.year,
      title: { ru: work.title, en: work.english },
      description: { ru: work.description, en: work.descriptionEn },
      releaseStatus: { ru: work.status, en: work.statusEn },
      releaseState: work.releaseState,
      dossierUrl: origin + '/osa-cinema/studio/films/' + work.id,
      artworkUrl: origin + '/osa-cinema/reference/' + work.artwork,
      interactiveUrl: isInteractive ? origin + '/osa-cinema' : null,
      publicVideoAvailable: false,
      publicVideoUrl: null,
      production: { verified: work.gates.filter(g => g.state === 'verified').length, total: work.gates.length },
    }
  })
  return {
    schema: PUBLIC_CATALOG_SCHEMA,
    version: 1,
    publisher: 'OSA CINEMA',
    homepage: origin + '/osa-cinema/studio',
    languages: ['ru', 'en'],
    publicPremiereClaimed: false,
    catalogueIsNotStreamingAuthorization: true,
    total: projects.length,
    projects,
  }
}
