import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import DashboardLayoutAccount from './components/AdminDashboard';

import './App.css';

function App() {
  return (
    <BrowserRouter>
      <div className="App">
        <Routes>
          <Route path="/admin" element={<DashboardLayoutAccount />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
