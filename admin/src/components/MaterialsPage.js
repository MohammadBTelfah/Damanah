import React, { useState, useEffect } from 'react';
import axios from 'axios';
import * as XLSX from 'xlsx'; // 1. استدعاء مكتبة الإكسل
import {
  Box, Button, Container, Paper, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, IconButton, Typography,
  Collapse, Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, Grid, Chip, ThemeProvider, createTheme, CssBaseline,
  Alert
} from '@mui/material';
import {
  Delete as DeleteIcon,
  Edit as EditIcon,
  Add as AddIcon,
  KeyboardArrowDown,
  KeyboardArrowUp,
  Save as SaveIcon,
  CloudUpload as CloudUploadIcon,
  FileDownload as FileDownloadIcon
} from '@mui/icons-material';

const API_URL = "http://localhost:5000/api/materials"; 

const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: { main: '#90caf9' },
    secondary: { main: '#f48fb1' },
    background: { default: '#121212', paper: '#1e1e1e' },
  },
});

// --- Component: Row ---
function Row({ row, onDelete, onEdit }) {
  const [open, setOpen] = useState(false);

  return (
    <React.Fragment>
      <TableRow sx={{ '& > *': { borderBottom: 'unset' } }}>
        <TableCell>
          <IconButton size="small" onClick={() => setOpen(!open)}>
            {open ? <KeyboardArrowUp /> : <KeyboardArrowDown />}
          </IconButton>
        </TableCell>
        <TableCell component="th" scope="row" sx={{ fontWeight: 'bold', fontSize: '1.1rem' }}>
          {row.name}
        </TableCell>
        <TableCell>{row.unit}</TableCell>
        <TableCell align="right">
          <Chip label={`${row.variants.length} Variants`} size="small" color="primary" variant="outlined" />
        </TableCell>
        <TableCell align="right">
          <IconButton color="primary" onClick={() => onEdit(row)}>
            <EditIcon />
          </IconButton>
          <IconButton color="error" onClick={() => onDelete(row._id)}>
            <DeleteIcon />
          </IconButton>
        </TableCell>
      </TableRow>
      <TableRow>
        <TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={6}>
          <Collapse in={open} timeout="auto" unmountOnExit>
            <Box sx={{ margin: 2 }}>
              <Typography variant="h6" gutterBottom component="div" sx={{ fontSize: '0.9rem', color: '#aaa' }}>
                Variants
              </Typography>
              <Table size="small" aria-label="variants">
                <TableHead>
                  <TableRow>
                    <TableCell>Label</TableCell>
                    <TableCell>Key</TableCell>
                    <TableCell align="right">Price / Unit</TableCell>
                    <TableCell align="right">Qty / m²</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {row.variants.map((variant, index) => (
                    <TableRow key={index}>
                      <TableCell>{variant.label}</TableCell>
                      <TableCell>{variant.key}</TableCell>
                      <TableCell align="right">{variant.pricePerUnit}</TableCell>
                      <TableCell align="right">{variant.quantityPerM2}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Box>
          </Collapse>
        </TableCell>
      </TableRow>
    </React.Fragment>
  );
}

export default function MaterialsPage() {
  const [materials, setMaterials] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [openBulk, setOpenBulk] = useState(false);
  
  // States needed
  const [currentMaterial, setCurrentMaterial] = useState({ name: '', unit: '', variants: [] });
  const [variantInput, setVariantInput] = useState({ key: '', label: '', pricePerUnit: '', quantityPerM2: '' });
  const [bulkJson, setBulkJson] = useState('');

  useEffect(() => { fetchMaterials(); }, []);

  const fetchMaterials = async () => {
    try {
      const res = await axios.get(API_URL);
      setMaterials(res.data);
    } catch (err) { console.error(err); }
  };

  // --- Excel Processing Logic ---
  const handleExcelUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const bstr = evt.target.result;
      const wb = XLSX.read(bstr, { type: 'binary' });
      const wsName = wb.SheetNames[0];
      const ws = wb.Sheets[wsName];
      
      // تحويل الإكسل لبيانات خام (Array of Objects)
      const rawData = XLSX.utils.sheet_to_json(ws);
      
      // معالجة البيانات وتحويلها للهيكلية المطلوبة (Grouping by Material Name)
      const processedData = processExcelData(rawData);
      
      // وضع النتيجة في خانة النص ليتأكد المستخدم
      setBulkJson(JSON.stringify(processedData, null, 2));
    };
    reader.readAsBinaryString(file);
  };

  const processExcelData = (data) => {
    const materialsMap = {};

    data.forEach(row => {
      // أسماء الأعمدة المتوقعة في ملف الإكسل
      // Name | Unit | VariantKey | VariantLabel | Price | QtyPerM2
      const name = row['Name'] || row['name'];
      const unit = row['Unit'] || row['unit'];
      
      if (!name) return;

      if (!materialsMap[name]) {
        materialsMap[name] = {
          name: name,
          unit: unit || 'Piece', // Default unit if missing
          variants: []
        };
      }

      // إضافة الـ Variant إذا وجد بيانات له في السطر
      if (row['Price'] || row['price']) {
        materialsMap[name].variants.push({
          key: row['VariantKey'] || row['key'] || `var_${Date.now()}_${Math.floor(Math.random()*1000)}`,
          label: row['VariantLabel'] || row['label'] || 'Standard',
          pricePerUnit: Number(row['Price'] || row['price']),
          quantityPerM2: Number(row['QtyPerM2'] || row['qty'] || 0)
        });
      }
    });

    return Object.values(materialsMap);
  };

  // --- Handlers ---
  const handleOpenDialog = (material = null) => {
    if (material) setCurrentMaterial(material);
    else setCurrentMaterial({ name: '', unit: '', variants: [] });
    setVariantInput({ key: '', label: '', pricePerUnit: '', quantityPerM2: '' });
    setOpenDialog(true);
  };

  const addVariantToForm = () => {
    if (!variantInput.label || !variantInput.pricePerUnit) return;
    setCurrentMaterial(prev => ({
      ...prev,
      variants: [...prev.variants, { ...variantInput, pricePerUnit: Number(variantInput.pricePerUnit), quantityPerM2: Number(variantInput.quantityPerM2) }]
    }));
    setVariantInput({ key: '', label: '', pricePerUnit: '', quantityPerM2: '' });
  };

  const removeVariantFromForm = (idx) => {
    const updated = currentMaterial.variants.filter((_, i) => i !== idx);
    setCurrentMaterial({ ...currentMaterial, variants: updated });
  };

  const handleSave = async () => {
    try {
      if (currentMaterial._id) await axios.put(`${API_URL}/${currentMaterial._id}`, currentMaterial);
      else await axios.post(API_URL, currentMaterial);
      fetchMaterials(); setOpenDialog(false);
    } catch (err) { alert("Error saving"); }
  };

  const handleDelete = async (id) => {
    if (window.confirm("Delete?")) {
      await axios.delete(`${API_URL}/${id}`);
      fetchMaterials();
    }
  };

  const handleBulkSubmit = async () => {
    try {
      const data = JSON.parse(bulkJson);
      if (!Array.isArray(data)) return alert("Must be an array");
      await axios.post(`${API_URL}/bulk`, data);
      alert(`Imported ${data.length} materials!`);
      setOpenBulk(false); setBulkJson(''); fetchMaterials();
    } catch (err) { alert("Invalid JSON"); }
  };

  // --- Template Downloader ---
  const downloadTemplate = () => {
    const ws = XLSX.utils.json_to_sheet([
      { Name: "Cement", Unit: "Ton", VariantKey: "manaseer", VariantLabel: "Manaseer", Price: 95, QtyPerM2: 0.02 },
      { Name: "Cement", Unit: "Ton", VariantKey: "lafarge", VariantLabel: "Lafarge", Price: 92, QtyPerM2: 0.02 },
      { Name: "Ceramic", Unit: "m2", VariantKey: "spain", VariantLabel: "Spanish", Price: 15, QtyPerM2: 1.05 }
    ]);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Template");
    XLSX.writeFile(wb, "Materials_Template.xlsx");
  };

  return (
    <ThemeProvider theme={darkTheme}>
      <CssBaseline />
      <Container maxWidth="lg" sx={{ mt: 5 }}>
        <Box display="flex" justifyContent="space-between" mb={4}>
          <Typography variant="h4" fontWeight="bold">Materials Manager</Typography>
          <Box>
            <Button variant="outlined" color="secondary" startIcon={<CloudUploadIcon />} onClick={() => setOpenBulk(true)} sx={{ mr: 2 }}>
              Bulk Import
            </Button>
            <Button variant="contained" startIcon={<AddIcon />} onClick={() => handleOpenDialog()}>
              Add Material
            </Button>
          </Box>
        </Box>

        <TableContainer component={Paper} elevation={3}>
          <Table>
            <TableHead sx={{ bgcolor: '#2c2c2c' }}>
              <TableRow>
                <TableCell />
                <TableCell sx={{ color: 'white' }}>Material Name</TableCell>
                <TableCell sx={{ color: 'white' }}>Unit</TableCell>
                <TableCell sx={{ color: 'white' }} align="right">Status</TableCell>
                <TableCell sx={{ color: 'white' }} align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {materials.map((row) => (
                <Row key={row._id} row={row} onDelete={handleDelete} onEdit={handleOpenDialog} />
              ))}
            </TableBody>
          </Table>
        </TableContainer>

        {/* --- Add/Edit Dialog --- */}
        <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="md" fullWidth>
          <DialogTitle>{currentMaterial._id ? "Edit" : "Add"} Material</DialogTitle>
          <DialogContent dividers>
            <Grid container spacing={2} mb={3}>
              <Grid item xs={8}><TextField label="Name" fullWidth value={currentMaterial.name} onChange={(e) => setCurrentMaterial({ ...currentMaterial, name: e.target.value })} /></Grid>
              <Grid item xs={4}><TextField label="Unit" fullWidth value={currentMaterial.unit} onChange={(e) => setCurrentMaterial({ ...currentMaterial, unit: e.target.value })} /></Grid>
            </Grid>
            <Typography variant="subtitle1" gutterBottom>Variants</Typography>
            <Paper variant="outlined" sx={{ p: 2, mb: 2, bgcolor: 'rgba(255,255,255,0.05)' }}>
              <Grid container spacing={2} alignItems="center">
                <Grid item xs={3}><TextField label="Key" size="small" fullWidth value={variantInput.key} onChange={(e) => setVariantInput({...variantInput, key: e.target.value})} /></Grid>
                <Grid item xs={3}><TextField label="Label" size="small" fullWidth value={variantInput.label} onChange={(e) => setVariantInput({...variantInput, label: e.target.value})} /></Grid>
                <Grid item xs={2}><TextField label="Price" type="number" size="small" fullWidth value={variantInput.pricePerUnit} onChange={(e) => setVariantInput({...variantInput, pricePerUnit: e.target.value})} /></Grid>
                <Grid item xs={2}><TextField label="Qty/m2" type="number" size="small" fullWidth value={variantInput.quantityPerM2} onChange={(e) => setVariantInput({...variantInput, quantityPerM2: e.target.value})} /></Grid>
                <Grid item xs={2}><Button variant="outlined" onClick={addVariantToForm}>Add</Button></Grid>
              </Grid>
            </Paper>
            <Box>
              {currentMaterial.variants.map((v, idx) => (
                <Chip key={idx} label={`${v.label} (${v.pricePerUnit})`} onDelete={() => removeVariantFromForm(idx)} sx={{ m: 0.5 }} />
              ))}
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpenDialog(false)}>Cancel</Button>
            <Button onClick={handleSave} variant="contained">Save</Button>
          </DialogActions>
        </Dialog>

        {/* --- Bulk Import Dialog --- */}
        <Dialog open={openBulk} onClose={() => setOpenBulk(false)} maxWidth="md" fullWidth>
          <DialogTitle>Bulk Import (JSON or Excel)</DialogTitle>
          <DialogContent dividers>
            <Box mb={2} display="flex" justifyContent="space-between" alignItems="center">
               <Typography variant="body2" color="text.secondary">
                 Upload an Excel file (.xlsx) or paste JSON array below.
               </Typography>
               <Button size="small" startIcon={<FileDownloadIcon />} onClick={downloadTemplate}>
                 Download Excel Template
               </Button>
            </Box>
            
            {/* زر رفع الملف */}
            <Button
              variant="contained"
              component="label"
              fullWidth
              sx={{ mb: 2, bgcolor: '#333' }}
            >
              Upload Excel File
              <input
                type="file"
                hidden
                accept=".xlsx, .xls"
                onChange={handleExcelUpload}
              />
            </Button>

            <TextField
              multiline
              rows={10}
              fullWidth
              variant="outlined"
              placeholder='[ { "name": "...", "variants": [...] } ]'
              value={bulkJson}
              onChange={(e) => setBulkJson(e.target.value)}
              sx={{ fontFamily: 'monospace', bgcolor: '#1e1e1e' }}
            />
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpenBulk(false)}>Cancel</Button>
            <Button onClick={handleBulkSubmit} variant="contained" color="secondary">
              Import Data
            </Button>
          </DialogActions>
        </Dialog>

      </Container>
    </ThemeProvider>
  );
}