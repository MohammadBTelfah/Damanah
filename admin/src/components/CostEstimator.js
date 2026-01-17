import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  Container, Paper, Typography, Box, Grid, TextField, MenuItem,
  Select, FormControl, InputLabel, Card, CardContent, Divider,
  ThemeProvider, createTheme, CssBaseline
} from '@mui/material';
import {
  Calculate as CalculateIcon,
  SquareFoot as AreaIcon,
  AttachMoney as MoneyIcon,
  Inventory2 as QtyIcon
} from '@mui/icons-material';

const API_URL = "http://localhost:5000/api/materials"; 

// نفس الثيم الداكن المستخدم في صفحاتك
const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: { main: '#90caf9' },
    secondary: { main: '#f48fb1' },
    background: { default: '#121212', paper: '#1e1e1e' },
  },
});

export default function CostEstimator() {
  const [materials, setMaterials] = useState([]);
  
  // Inputs States
  const [selectedMaterialId, setSelectedMaterialId] = useState('');
  const [selectedVariantKey, setSelectedVariantKey] = useState('');
  const [area, setArea] = useState('');

  // Results States
  const [result, setResult] = useState({ cost: 0, quantity: 0, unit: '' });

  // 1. Fetch Materials on Load
  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await axios.get(API_URL);
        setMaterials(res.data);
      } catch (err) {
        console.error("Error fetching materials", err);
      }
    };
    fetchData();
  }, []);

  // 2. Calculation Logic (Runs whenever inputs change)
  useEffect(() => {
    if (!selectedMaterialId || !selectedVariantKey || !area) {
      setResult({ cost: 0, quantity: 0, unit: '' });
      return;
    }

    const material = materials.find(m => m._id === selectedMaterialId);
    if (!material) return;

    const variant = material.variants.find(v => v.key === selectedVariantKey);
    if (!variant) return;

    // المعادلة: الكمية = المساحة * الاستهلاك للمتر
    const totalQty = parseFloat(area) * variant.quantityPerM2;
    // المعادلة: التكلفة = الكمية الكلية * سعر الوحدة
    const totalCost = totalQty * variant.pricePerUnit;

    setResult({
      quantity: Math.ceil(totalQty), // تقريب لأقرب عدد صحيح (مثلا ما بشتري نص طوبة)
      cost: totalCost.toFixed(2),    // خانتين عشريتين للسعر
      unit: material.unit
    });

  }, [selectedMaterialId, selectedVariantKey, area, materials]);

  // Helper to get variants list based on selected material
  const currentMaterial = materials.find(m => m._id === selectedMaterialId);
  const currentVariants = currentMaterial ? currentMaterial.variants : [];

  return (
    <ThemeProvider theme={darkTheme}>
      <CssBaseline />
      <Container maxWidth="md" sx={{ mt: 5 }}>
        
        {/* Header */}
        <Box display="flex" alignItems="center" mb={4} gap={2}>
          <CalculateIcon sx={{ fontSize: 40, color: 'primary.main' }} />
          <Typography variant="h4" fontWeight="bold">
            Project Cost Estimator
          </Typography>
        </Box>

        <Paper elevation={3} sx={{ p: 4, borderRadius: 2 }}>
          <Grid container spacing={3}>
            
            {/* 1. Select Material */}
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Select Material</InputLabel>
                <Select
                  value={selectedMaterialId}
                  label="Select Material"
                  onChange={(e) => {
                    setSelectedMaterialId(e.target.value);
                    setSelectedVariantKey(''); // Reset variant when material changes
                  }}
                >
                  {materials.map((m) => (
                    <MenuItem key={m._id} value={m._id}>{m.name}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>

            {/* 2. Select Type (Variant) */}
            <Grid item xs={12} md={6}>
              <FormControl fullWidth disabled={!selectedMaterialId}>
                <InputLabel>Select Type / Variant</InputLabel>
                <Select
                  value={selectedVariantKey}
                  label="Select Type / Variant"
                  onChange={(e) => setSelectedVariantKey(e.target.value)}
                >
                  {currentVariants.map((v) => (
                    <MenuItem key={v.key} value={v.key}>
                      {v.label} (Price: {v.pricePerUnit} JOD)
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>

            {/* 3. Input Area */}
            <Grid item xs={12}>
              <TextField
                label="Total Area / Size (m²)"
                type="number"
                fullWidth
                value={area}
                onChange={(e) => setArea(e.target.value)}
                InputProps={{
                  startAdornment: <AreaIcon sx={{ mr: 1, color: 'gray' }} />,
                }}
                placeholder="Ex: 150"
              />
              {selectedVariantKey && (
                <Typography variant="caption" color="text.secondary" sx={{ ml: 1, mt: 1, display: 'block' }}>
                  * Based on {currentVariants.find(v => v.key === selectedVariantKey)?.quantityPerM2} {currentMaterial?.unit} per m²
                </Typography>
              )}
            </Grid>

          </Grid>

          <Divider sx={{ my: 4 }} />

          {/* Results Section */}
          <Grid container spacing={3}>
            
            {/* Cost Card */}
            <Grid item xs={12} md={6}>
              <Card sx={{ bgcolor: 'rgba(144, 202, 249, 0.08)', border: '1px solid #90caf9' }}>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography color="primary" gutterBottom>
                    <MoneyIcon sx={{ verticalAlign: 'middle', mr: 1 }} />
                    Estimated Cost
                  </Typography>
                  <Typography variant="h3" fontWeight="bold" color="white">
                    {result.cost} <span style={{ fontSize: '1.5rem' }}>JOD</span>
                  </Typography>
                </CardContent>
              </Card>
            </Grid>

            {/* Quantity Card */}
            <Grid item xs={12} md={6}>
              <Card sx={{ bgcolor: 'rgba(244, 143, 177, 0.08)', border: '1px solid #f48fb1' }}>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography color="secondary" gutterBottom>
                    <QtyIcon sx={{ verticalAlign: 'middle', mr: 1 }} />
                    Required Quantity
                  </Typography>
                  <Typography variant="h3" fontWeight="bold" color="white">
                    {result.quantity} <span style={{ fontSize: '1.5rem' }}>{result.unit}</span>
                  </Typography>
                </CardContent>
              </Card>
            </Grid>

          </Grid>
        </Paper>
      </Container>
    </ThemeProvider>
  );
}