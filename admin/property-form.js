
const API = 'https://admin-api.keydhan.com/api/properties';

let data = [];
let editing = null;

const $ = id => document.getElementById(id);

const esc = value =>
  String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[char]);

function toast(message) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2200);
}

async function load() {
  const statusEl = $('status');
  const tableEl = $('table');

  try {
    const response = await fetch(API, { cache: 'no-store' });

    if (!response.ok) {
      throw new Error(`API error: HTTP ${response.status}`);
    }

    const result = await response.json();

    data = Array.isArray(result)
      ? result
      : Array.isArray(result.properties)
        ? result.properties
        : [];

    if (statusEl) statusEl.textContent = 'Live';
    render();
  } catch (error) {
    if (statusEl) statusEl.textContent = 'Error';

    if (tableEl) {
      tableEl.innerHTML =
        '<tr><td colspan="6" class="empty">API connection failed. Check Console.</td></tr>';
    }

    console.error('Property load failed:', error);
  }
}

function render() {
  const searchEl = $('search');
  const tableEl = $('table');
  const countEl = $('count');
  const featuredEl = $('featured');

  if (!tableEl) {
    console.error('Property table element not found.');
    return;
  }

  const query = (searchEl?.value || '').toLowerCase();

  const filtered = data.filter(property =>
    `${property.title || ''} ${property.location || ''}`
      .toLowerCase()
      .includes(query)
  );

  if (countEl) countEl.textContent = data.length;
  if (featuredEl) {
    featuredEl.textContent =
      data.filter(property => property.featured).length;
  }

  tableEl.innerHTML = filtered.map(property => `
    <tr>
      <td>
        <img class="thumb"
             src="${esc(property.image)}"
             alt=""
             onerror="this.style.opacity='.2'">
      </td>
      <td>${esc(property.title)}</td>
      <td>${esc(property.location)}</td>
      <td>${esc(property.price)}</td>
      <td>${property.featured ? '⭐' : '—'}</td>
      <td>
        <div class="actions">
          <button type="button" class="btn alt"
            onclick="edit('${encodeURIComponent(property.id)}')">
            Edit
          </button>
          <button type="button" class="btn danger"
            onclick="del('${encodeURIComponent(property.id)}')">
            Delete
          </button>
        </div>
      </td>
    </tr>
  `).join('') ||
    '<tr><td colspan="6" class="empty">No properties</td></tr>';
}

window.edit = key => {
  const property = data.find(
    item => String(item.id) === decodeURIComponent(key)
  );

  if (!property) return;

  editing = property.id;

  const fields = {
    title: property.title,
    location: property.location,
    price: property.price,
    type: property.type || 'Residential',
    bedrooms: property.bedrooms,
    bathrooms: property.bathrooms,
    area: property.area,
    whatsapp: property.whatsapp,
    image: property.image,
    mapUrl: property.mapUrl,
    desc: property.desc
  };

  Object.entries(fields).forEach(([id, value]) => {
    const element = $(id);
    if (element) element.value = value ?? '';
  });

  if ($('statSel')) {
    $('statSel').value = property.status || 'published';
  }

  if ($('feat')) $('feat').checked = !!property.featured;
  if ($('ft')) $('ft').textContent = 'Edit Property';
  if ($('save')) $('save').textContent = 'Update Property';
  if ($('cancel')) $('cancel').style.display = 'inline-block';

  window.scrollTo({ top: 0, behavior: 'smooth' });
};

window.del = async key => {
  if (!confirm('Delete this property?')) return;

  try {
    const response = await fetch(
      API + '/' + encodeURIComponent(decodeURIComponent(key)),
      { method: 'DELETE' }
    );

    if (!response.ok) {
      throw new Error(`Delete failed: HTTP ${response.status}`);
    }

    toast('Deleted');
    await load();
  } catch (error) {
    alert(error.message);
    console.error('Property delete failed:', error);
  }
};

const formEl = $('form');
const saveEl = $('save');

if (formEl) {
  formEl.addEventListener('submit', async event => {
    event.preventDefault();

    if (!saveEl) {
      alert('Save button not found.');
      return;
    }

    if (saveEl.disabled) return;
    saveEl.disabled = true;

    const getValue = id => $(id)?.value?.trim() || '';

    const property = {
      title: getValue('title'),
      location: getValue('location'),
      price: getValue('price'),
      type: getValue('type') || 'Residential',
      bedrooms: getValue('bedrooms'),
      bathrooms: getValue('bathrooms'),
      area: getValue('area'),
      whatsapp: getValue('whatsapp'),
      image: getValue('image'),
      mapUrl: getValue('mapUrl'),
      desc: getValue('desc'),
      status: getValue('statSel') || 'published',
      featured: !!$('feat')?.checked
    };

    if (!property.title || !property.location || !property.price) {
      alert('Please enter property title, location and price.');
      saveEl.disabled = false;
      return;
    }

    try {
      const url = editing !== null
        ? API + '/' + encodeURIComponent(editing)
        : API;

      const response = await fetch(url, {
        method: editing !== null ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(property)
      });

      const raw = await response.text();
      let result;

      try {
        result = JSON.parse(raw);
      } catch {
        throw new Error(
          `Invalid API response (HTTP ${response.status}): ${raw.slice(0, 200)}`
        );
      }

      if (!response.ok || result.success !== true) {
        throw new Error(
          result.error || `Save failed (HTTP ${response.status})`
        );
      }

      toast(editing !== null ? 'Property updated' : 'Property added');

      reset();
      await load();
    } catch (error) {
      alert(error.message || 'Unable to save property.');
      console.error('Property save failed:', error);
    } finally {
      saveEl.disabled = false;
    }
  });
} else {
  console.error('Property form element #form not found.');
}

function reset() {
  editing = null;

  if ($('form')) $('form').reset();
  if ($('ft')) $('ft').textContent = 'Add Property';
  if ($('save')) $('save').textContent = 'Save Property';
  if ($('cancel')) $('cancel').style.display = 'none';
}

if ($('cancel')) {
  $('cancel').addEventListener('click', reset);
}

if ($('search')) {
  $('search').addEventListener('input', render);
}

window.logout = function () {
  localStorage.clear();
  sessionStorage.clear();

  window.location.href =
    '/cdn-cgi/access/logout?returnTo=' +
    encodeURIComponent('https://keydhan.com/admin/');
};

load();
