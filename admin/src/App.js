import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import DashboardLayoutAccount from "./components/AdminDashboard";
import AdminRegister from "./components/AdminRegister";
import AdminVerifyEmail from "./components/AdminVerifyEmail";
import AdminLogin from "./components/AdminLogin";

import "./App.css";

function App() {
  return (
    <BrowserRouter>
      <div className="App">
        <Routes>
          <Route path="/admin/register" element={<AdminRegister />} />
          <Route path="/" element={<DashboardLayoutAccount />} />
          <Route
            path="/admin/verify-email/:token"
            element={<AdminVerifyEmail />}
          />
          <Route path="/admin/login" element={<AdminLogin />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
