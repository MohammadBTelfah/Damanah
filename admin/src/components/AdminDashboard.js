import * as React from "react";
import PropTypes from "prop-types";
import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import { createTheme } from "@mui/material/styles";
import DashboardIcon from "@mui/icons-material/Dashboard";
import PersonIcon from "@mui/icons-material/Person";
import { AppProvider } from "@toolpad/core/AppProvider";
import { DashboardLayout } from "@toolpad/core/DashboardLayout";
import { DemoProvider, useDemoRouter } from "@toolpad/core/internal";
import GroupIcon from "@mui/icons-material/Group";
import BadgeIcon from "@mui/icons-material/Badge";
import AssignmentLateIcon from "@mui/icons-material/AssignmentLate";


import AdminLogin from "../components/AdminLogin";
import AdminProfile from "../components/AdminProfile";
import AdminUsersPage from "../components/AdminUsersPage";
import AdminIdentityPendingPage from "./AdminIdentityPendingPage";
import AdminPendingContractorsPage from "./AdminPendingContractorsPage";
import AdminDashboardHome from "../components/AdminDashboardHome";


const NAVIGATION = [
  {
    segment: "dashboard",
    title: "Dashboard",
    icon: <DashboardIcon />,
  },
  {
    segment: "profile",
    title: "Profile",
    icon: <PersonIcon />,
  },
  {
    segment: "users",
    title: "Users",
    icon: <GroupIcon />,
  },
  {
    segment: "identity-pending",
    title: "Pending Identities",
    icon: <BadgeIcon />,
  },
  {
    segment: "contractors-pending",
    title: "Pending Contractors",
    icon: <AssignmentLateIcon />,
  },
];


const demoTheme = createTheme({
  cssVariables: { colorSchemeSelector: "data-toolpad-color-scheme" },
  colorSchemes: { light: true, dark: true },
  breakpoints: { values: { xs: 0, sm: 600, md: 600, lg: 1200, xl: 1536 } },
});

function DemoPageContent({ pathname }) {
  return (
    <Box
      sx={{
        py: 4,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        textAlign: "center",
      }}
    >
      <Typography>Dashboard content for {pathname}</Typography>
    </Box>
  );
}
DemoPageContent.propTypes = { pathname: PropTypes.string.isRequired };

// ✅ بدل DemoPageContent مباشرة، نعمل سويتش حسب المسار
function PageSwitch({ pathname }) {
  if (pathname === "/dashboard") {
    return <AdminDashboardHome />;
  }
  if (pathname === "/profile") {
    return <AdminProfile />;
  }

  if (pathname === "/users") {
    return <AdminUsersPage />;
  }
  if (pathname === "/identity-pending") {
    return <AdminIdentityPendingPage />;
  }
  if (pathname === "/contractors-pending") {
    return <AdminPendingContractorsPage />;
  }
  return <DemoPageContent pathname={pathname} />;

}
PageSwitch.propTypes = { pathname: PropTypes.string.isRequired };

const SESSION_KEY = "admin_session";

function loadSession(win) {
  try {
    const storage = win?.localStorage ?? localStorage;
    const raw = storage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveSession(win, session) {
  try {
    const storage = win?.localStorage ?? localStorage;
    if (session) storage.setItem(SESSION_KEY, JSON.stringify(session));
    else storage.removeItem(SESSION_KEY);
  } catch {}
}

export default function DashboardLayoutAccount(props) {
  const { window } = props;
  const router = useDemoRouter("/dashboard");
  const demoWindow = window !== undefined ? window() : undefined;

  const [session, setSession] = React.useState(() => loadSession(demoWindow));

  // ✅ دائماً نفذ hooks بنفس الترتيب
  React.useEffect(() => {
    saveSession(demoWindow, session);
  }, [session, demoWindow]);

  const isLoginRoute = router.pathname === "/admin/login";

  // ✅ حماية الصفحات: إذا مش لوقن ومش على صفحة اللوقن -> روح للوقن
  React.useEffect(() => {
    if (!isLoginRoute && !session?.token) {
      router.navigate("/admin/login");
    }
  }, [isLoginRoute, session, router]);

  // ✅ إذا صفحة اللوقن اعرض AdminLogin فقط
  if (isLoginRoute) {
    return (
      <AdminLogin
        onLoggedIn={(nextSession) => {
          setSession(nextSession);
          router.navigate("/dashboard");
        }}
      />
    );
  }

  return (
    <DemoProvider window={demoWindow}>
      <AppProvider
        navigation={NAVIGATION}
        router={router}
        theme={demoTheme}
        window={demoWindow}
        session={session}
        authentication={{
          signOut: async () => {
            setSession(null);
            router.navigate("/admin/login");
          },
        }}
        localeText={{
          accountSignOutLabel: "Logout",
          accountSignInLabel: "Login",
        }}
      >
        <DashboardLayout>
          <PageSwitch pathname={router.pathname} />
        </DashboardLayout>
      </AppProvider>
    </DemoProvider>
  );
}

DashboardLayoutAccount.propTypes = { window: PropTypes.func };
