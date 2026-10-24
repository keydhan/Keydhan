
'use strict';

const API = 'https://admin-api.keydhan.com/api/properties';

let data = [];
let editing = null;
let loading = false;

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
  setTimeout(() => el.remove(), 2500);
}

function setStatus(message) {
  const el = $('status');
  if (el) el.textContent = message;
}

function setErrorRow(message) {
  const table = $('table');
  if (table) {
    table.innerHTML =
      `<tr><td colspan="6" class="empty">${esc(message)}</td></tr>`;
  }
}

async function readResponse(response) {
  const raw = await response.text();

  let result;
  try {
    result = JSON.parse(raw);
  } catch {
    throw new Error(
      `Invalid API response (HTTP ${response.status}). ` +
      raw.slice(0, 180)
    );
  }

  if (!response.ok) {
    throw new Error(
      result.error || result.message || `HTTP ${response.status}`
    );
  }

  return result;
}

async function load() {
  if (loading) return;
  loading = true;
  setStatus('Checking');

  try {
    const response = await fetch(API, {
      method: 'GET',
      cache: 'no-store',
      headers: { Accept: 'application/json' }
    });

    const result = await readResponse(response);

    if (Array.isArray(result)) {
      data = result;
    } else if (Array.isArray(result.properties)) {
      data = result.properties;
    } else {
      throw new Error('API response does not contain a properties array.');
    }

    setStatus('Live');
    render();
  } catch (error) {
    setStatus('Error');
    setErrorRow(error.message || 'Unable to load properties.');
    console.error('Property load failed:', error);
  } finally {
    loading = false;
  }
}

function render() {
  const table = $('table');
  if (!table) {
    console.error('Property table element #table not found.');
    return;
  }

  const query = ($('search')?.value || '').trim().toLowerCase();

  const filtered = data.filter(property =>
    `${property.title || ''} ${property.location || ''}`
      .toLowerCase()
      .includes(query)
  );

  if ($('count')) $('count').textContent = String(data.length);

  if ($('featured')) {
    $('featured').textContent = String(
      data.filter(property => property.featured).length
    );
  }

  if (!filtered.length) {
    setErrorRow(data.length ? 'No matching properties.' : 'No properties found.');
    return;
  }

  table.innerHTML = filtered.map(property => {
    const id = encodeURIComponent(String(property.id ?? ''));

    return `
      <tr>
        <td>
          <img class="thumb"
               src="${esc(property.image || '')}"
               alt="${esc(property.title || 'Property')}"
               onerror="this.style.opacity='.2'">
        </td>
        <td>${esc(property.title || '')}</td>
        <td>${esc(property.location || '')}</td>
        <td>${esc(property.price || '')}</td>
        <td>${property.featured ? '⭐' : '—'}</td>
        <td>
          <div class="actions">
            <button type="button" class="btn alt"
              data-action="edit" data-id="${id}">Edit</button>
            <button type="button" class="btn danger"
              data-action="delete" data-id="${id}">Delete</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function editProperty(key) {
  const id = decodeURIComponent(key);
  const property = data.find(item => String(item.id) === id);

  if (!property) {
    alert('Property not found. Please refresh the page.');
    return;
  }

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
    desc: property.description ?? property.desc ?? ''
  };

  Object.entries(fields).forEach(([id, value]) => {
    const el = $(id);
    if (el) el.value = value ?? '';
  });

  if ($('statSel')) {
    $('statSel').value = property.status || 'published';
  }

  if ($('feat')) $('feat').checked = !!property.featured;
  if ($('ft')) $('ft').textContent = 'Edit Property';
  if ($('save')) $('save').textContent = 'Update Property';
  if ($('cancel')) $('cancel').style.display = 'inline-block';

  window.scrollTo({ top: 0, behavior: 'smooth' });
}

window.edit = editProperty;

async function deleteProperty(key) {
  const id = decodeURIComponent(key);

  if (!confirm('Delete this property?')) return;

  try {
    const response = await fetch(
      `${API}/${encodeURIComponent(id)}`,
      { method: 'DELETE' }
    );

    const result = await readResponse(response);

    if (result.success === false) {
      throw new Error(result.error || 'Delete failed.');
    }

    toast('Property deleted.');
    await load();
  } catch (error) {
    console.error('Property delete failed:', error);
    alert(error.message || 'Unable to delete property.');
  }
}

window.del = deleteProperty;

function reset() {
  editing = null;

  if ($('form')) $('form').reset();
  if ($('ft')) $('ft').textContent = 'Add Property';
  if ($('save')) $('save').textContent = 'Save Property';
  if ($('cancel')) $('cancel').style.display = 'none';
}

const tableEl = $('table');

if (tableEl) {
  tableEl.addEventListener('click', event => {
    const button = event.target.closest('button[data-action]');
    if (!button) return;

    const id = button.dataset.id;
    if (!id) return;

    if (button.dataset.action === 'edit') {
      editProperty(id);
    } else if (button.dataset.action === 'delete') {
      deleteProperty(id);
    }
  });
}

const formEl = $('form');
const saveEl = $('save');

if (formEl) {
  formEl.addEventListener('submit', async event => {
    event.preventDefault();

    if (!saveEl || saveEl.disabled) return;

    const getValue = id => $(id)?.value?.trim() || '';

    const description = getValue('desc');

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
      description,
      status: getValue('statSel') || 'published',
      featured: !!$('feat')?.checked
    };

    if (!property.title || !property.location || !property.price) {
      alert('Please enter property title, location and price.');
      return;
    }

    saveEl.disabled = true;
    const originalLabel = saveEl.textContent;
    saveEl.textContent = 'Saving...';

    try {
      const isEditing = editing !== null;
      const url = isEditing
        ? `${API}/${encodeURIComponent(String(editing))}`
        : API;

      const response = await fetch(url, {
        method: isEditing ? 'PUT' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(property)
      });

      const result = await readResponse(response);

      if (result.success !== true) {
        throw new Error(
          result.error || result.message || 'API did not confirm the save.'
        );
      }

      toast(isEditing ? 'Property updated.' : 'Property added.');
      reset();
      await load();
    } catch (error) {
      console.error('Property save failed:', error);
      alert(`Save failed: ${error.message || 'Unknown error'}`);
    } finally {
      saveEl.disabled = false;
      saveEl.textContent = originalLabel === 'Saving...'
        ? (editing !== null ? 'Update Property' : 'Save Property')
        : originalLabel;
    }
  });
} else {
  console.error('Property form element #form not found.');
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
