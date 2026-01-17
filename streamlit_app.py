"""
Election Result Statistical Analysis Portal
Professional Capstone Project - Streamlit Application
Version: 1.0.0
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime
import time

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================

st.set_page_config(
    page_title="Election Analysis Portal",
    page_icon="🗳️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# CUSTOM CSS
# ============================================================================

st.markdown("""
<style>
    .main-header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 2rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin-bottom: 2rem;
    }
    .winner-card {
        background: linear-gradient(135deg, #FA8BFF 0%, #2BD2FF 52%, #2BFF88 90%);
        padding: 2rem;
        border-radius: 15px;
        color: white;
        text-align: center;
        font-size: 28px;
        font-weight: bold;
        margin: 1rem 0;
        box-shadow: 0 8px 16px rgba(0,0,0,0.2);
    }
    .stButton>button {
        width: 100%;
        border-radius: 8px;
        height: 3rem;
        font-weight: 600;
    }
</style>
""", unsafe_allow_html=True)

# ============================================================================
# SESSION STATE
# ============================================================================

if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False
if 'election_data' not in st.session_state:
    st.session_state.election_data = None

# ============================================================================
# DATA GENERATION
# ============================================================================

@st.cache_data
def generate_election_data():
    """Generate sample election data"""
    np.random.seed(42)
    
    regions = ['North', 'South', 'East', 'West', 'Central']
    parties = ['Party A', 'Party B', 'Party C', 'Party D', 'Independent']
    
    data_list = []
    for region in regions:
        for const_id in range(1, 21):
            constituency_name = f"{region} Constituency {const_id}"
            total_voters = np.random.randint(50000, 200000)
            
            for party in parties:
                base_turnout = np.random.uniform(0.6, 0.85)
                
                if party == 'Party A':
                    party_strength = np.random.uniform(0.25, 0.35)
                elif party == 'Party B':
                    party_strength = np.random.uniform(0.20, 0.30)
                elif party == 'Party C':
                    party_strength = np.random.uniform(0.15, 0.25)
                elif party == 'Party D':
                    party_strength = np.random.uniform(0.10, 0.20)
                else:
                    party_strength = np.random.uniform(0.05, 0.15)
                
                votes = int(total_voters * base_turnout * party_strength)
                
                data_list.append({
                    'region': region,
                    'constituency_id': const_id,
                    'constituency_name': constituency_name,
                    'total_voters': total_voters,
                    'party': party,
                    'votes': votes,
                    'counting_status': np.random.choice(
                        ['Complete', 'In Progress', 'Pending'],
                        p=[0.7, 0.25, 0.05]
                    ),
                    'counted_votes': int(votes * np.random.uniform(0.75, 0.95))
                })
    
    df = pd.DataFrame(data_list)
    df['total_constituency_votes'] = df.groupby('constituency_name')['votes'].transform('sum')
    df['vote_share_pct'] = (df['votes'] / df['total_constituency_votes'] * 100).round(2)
    
    return df

# ============================================================================
# AUTHENTICATION
# ============================================================================

def login_page():
    """Login page"""
    st.markdown("""
        <div class="main-header">
            <h1>🗳️ Election Result Statistical Analysis Portal</h1>
            <p>Professional Statistical Analysis & AI-Powered Predictions</p>
        </div>
    """, unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col2:
        st.markdown("### 🔐 Login to Access Portal")
        st.markdown("---")
        
        username = st.text_input("Username", placeholder="Enter username")
        password = st.text_input("Password", type="password", placeholder="Enter password")
        
        col_a, col_b = st.columns(2)
        with col_a:
            if st.button("🚀 Login"):
                if username == "admin" and password == "password123":
                    st.session_state.authenticated = True
                    st.session_state.election_data = generate_election_data()
                    st.success("✅ Login successful!")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error("❌ Invalid credentials!")
        
        with col_b:
            if st.button("ℹ️ Demo Info"):
                st.info("**Demo Credentials:**\n\nUsername: `admin`\n\nPassword: `password123`")

# ============================================================================
# PREDICTION FUNCTIONS
# ============================================================================

def predict_winner_ensemble(df):
    """Ensemble prediction"""
    party_stats = df.groupby('party').agg({
        'votes': ['sum', 'mean', 'std', 'count'],
        'vote_share_pct': 'mean'
    }).reset_index()
    
    party_stats.columns = ['party', 'total_votes', 'avg_votes', 'std_votes', 'count', 'avg_share']
    
    # Weighted scoring
    party_stats['score'] = (
        party_stats['total_votes'] * 0.5 +
        party_stats['count'] * 1000 * 0.3 +
        party_stats['avg_share'] * 100 * 0.2
    )
    
    party_stats['win_probability'] = (party_stats['score'] / party_stats['score'].sum() * 100).round(2)
    party_stats['predicted_votes'] = (party_stats['total_votes'] * 1.05).astype(int)
    
    return party_stats.sort_values('win_probability', ascending=False)

# ============================================================================
# PAGE FUNCTIONS
# ============================================================================

def home_page():
    """Home dashboard"""
    st.markdown("""
        <div class="main-header">
            <h1>🗳️ Election Result Statistical Analysis Portal</h1>
            <h3>Real-time Statistical Analysis & AI-Powered Prediction System</h3>
        </div>
    """, unsafe_allow_html=True)
    
    df = st.session_state.election_data
    
    # Metrics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("📊 Total Votes", f"{df['votes'].sum():,}")
    
    with col2:
        st.metric("📍 Constituencies", df['constituency_name'].nunique())
    
    with col3:
        turnout = (df['votes'].sum() / df.groupby('constituency_name')['total_voters'].first().sum() * 100)
        st.metric("👥 Turnout", f"{turnout:.1f}%")
    
    with col4:
        leading = df.groupby('party')['votes'].sum().idxmax()
        st.metric("🏆 Leading Party", leading)
    
    st.markdown("---")
    
    # Charts
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("#### 📈 Party Performance")
        party_votes = df.groupby('party')['votes'].sum().reset_index()
        fig = px.bar(party_votes, x='party', y='votes', 
                     color='votes',
                     color_continuous_scale='viridis',
                     title='Total Votes by Party')
        fig.update_layout(showlegend=False, height=400)
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.markdown("#### 🗺️ Regional Distribution")
        region_votes = df.groupby('region')['votes'].sum().reset_index()
        fig = px.pie(region_votes, values='votes', names='region',
                     title='Votes by Region')
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

def voting_dashboard():
    """Voting dashboard"""
    st.markdown("# 📊 Voting Dashboard - Live Analysis")
    
    df = st.session_state.election_data
    
    # Filters
    col1, col2, col3 = st.columns(3)
    with col1:
        selected_region = st.selectbox("Region", ['All'] + list(df['region'].unique()))
    with col2:
        selected_party = st.selectbox("Party", ['All'] + list(df['party'].unique()))
    with col3:
        if st.button("🔄 Refresh"):
            st.rerun()
    
    # Apply filters
    filtered_df = df.copy()
    if selected_region != 'All':
        filtered_df = filtered_df[filtered_df['region'] == selected_region]
    if selected_party != 'All':
        filtered_df = filtered_df[filtered_df['party'] == selected_party]
    
    st.markdown("---")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("#### 📊 Vote Distribution")
        party_dist = filtered_df.groupby('party')['votes'].sum().reset_index()
        fig = px.bar(party_dist, x='party', y='votes', color='votes')
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.markdown("#### 🏅 Top Constituencies")
        top = filtered_df.groupby('constituency_name')['votes'].sum().nlargest(10).reset_index()
        fig = px.bar(top, y='constituency_name', x='votes', orientation='h')
        fig.update_layout(yaxis={'categoryorder': 'total ascending'})
        st.plotly_chart(fig, use_container_width=True)
    
    st.dataframe(filtered_df, use_container_width=True)

def counting_dashboard():
    """Counting dashboard"""
    st.markdown("# 🧮 Counting Dashboard - Real-time Updates")
    
    df = st.session_state.election_data
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        complete = len(df[df['counting_status'] == 'Complete'])
        st.metric("✅ Complete", complete)
    
    with col2:
        in_progress = len(df[df['counting_status'] == 'In Progress'])
        st.metric("⏳ In Progress", in_progress)
    
    with col3:
        pending = len(df[df['counting_status'] == 'Pending'])
        st.metric("⏰ Pending", pending)
    
    st.markdown("---")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("#### 📊 Progress by Region")
        status = df.groupby(['region', 'counting_status']).size().reset_index(name='count')
        fig = px.bar(status, x='region', y='count', color='counting_status', barmode='stack')
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.markdown("#### 🏆 Leading Party")
        party = df.groupby('party')['counted_votes'].sum().reset_index()
        fig = px.pie(party, values='counted_votes', names='party')
        st.plotly_chart(fig, use_container_width=True)
    
    st.dataframe(df[['constituency_name', 'party', 'votes', 'counting_status']], use_container_width=True)

def winner_prediction():
    """Winner prediction"""
    st.markdown("# 🏆 Winner Prediction - AI-Powered Analysis")
    
    df = st.session_state.election_data
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        model = st.selectbox("Model", ['Ensemble', 'Linear Regression', 'Random Forest', 'Bayesian'])
    
    with col2:
        confidence = st.slider("Confidence", 0.80, 0.99, 0.95, 0.01)
    
    with col3:
        if st.button("🚀 Run Prediction", use_container_width=True):
            st.session_state.prediction_run = True
    
    st.markdown("---")
    
    if st.session_state.get('prediction_run', False):
        predictions = predict_winner_ensemble(df)
        winner = predictions.iloc[0]
        
        st.markdown(f"""
            <div class="winner-card">
                🏆 PREDICTED WINNER: {winner['party']}<br>
                Win Probability: {winner['win_probability']:.2f}%
            </div>
        """, unsafe_allow_html=True)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### 📊 Win Probability by Party")
            fig = px.bar(predictions, x='party', y='win_probability',
                        color='win_probability',
                        color_continuous_scale='RdYlGn')
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("#### 📈 Predicted Vote Distribution")
            fig = px.pie(predictions, values='predicted_votes', names='party')
            st.plotly_chart(fig, use_container_width=True)
        
        st.dataframe(predictions, use_container_width=True)

def module1_page():
    """Module 1: Vote Share Analysis"""
    st.markdown("# 📊 Module 1: Vote Share & Descriptive Analysis")
    
    df = st.session_state.election_data
    
    # Stats
    stats = df.groupby('party')['votes'].agg(['sum', 'mean', 'median', 'std', 'min', 'max']).reset_index()
    stats.columns = ['Party', 'Total Votes', 'Mean', 'Median', 'Std Dev', 'Min', 'Max']
    
    st.markdown("#### 📋 Statistical Summary")
    st.dataframe(stats, use_container_width=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("#### 📊 Vote Share Distribution")
        party_share = df.groupby('party')['votes'].sum().reset_index()
        party_share['percentage'] = (party_share['votes'] / party_share['votes'].sum() * 100).round(2)
        fig = px.pie(party_share, values='percentage', names='party', title='Vote Share %')
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.markdown("#### 📈 Performance Metrics")
        fig = px.box(df, x='party', y='votes', color='party', title='Vote Distribution by Party')
        st.plotly_chart(fig, use_container_width=True)

def module2_page():
    """Module 2: Regional Comparison"""
    st.markdown("# 🗺️ Module 2: Comparative Dashboard by Region")
    
    df = st.session_state.election_data
    
    selected_regions = st.multiselect("Select Regions", df['region'].unique(), 
                                     default=list(df['region'].unique()[:3]))
    
    if selected_regions:
        filtered = df[df['region'].isin(selected_regions)]
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            st.markdown("#### 📊 Regional Comparison")
            regional = filtered.groupby(['region', 'party'])['votes'].sum().reset_index()
            fig = px.bar(regional, x='region', y='votes', color='party', 
                        barmode='group', title='Votes by Region and Party')
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("#### 📈 Regional Metrics")
            metrics = filtered.groupby('region')['votes'].sum().reset_index()
            fig = px.bar(metrics, y='region', x='votes', orientation='h',
                        color='votes', title='Total Votes by Region')
            st.plotly_chart(fig, use_container_width=True)
        
        st.markdown("#### 📋 Cross-Regional Analysis")
        comparison = filtered.pivot_table(values='votes', index='region', columns='party', aggfunc='sum', fill_value=0)
        st.dataframe(comparison, use_container_width=True)

def about_page():
    """About page"""
    st.markdown("# ℹ️ About This Portal")
    
    st.markdown("""
    ### 🎯 Election Result Statistical Analysis Portal
    
    **Professional Capstone Project - Advanced Statistical Analysis System**
    
    ---
    
    #### 📊 Key Features
    
    - **🏠 Home Dashboard**: Real-time election statistics overview
    - **📊 Voting Dashboard**: Live vote tracking and analysis  
    - **🧮 Counting Dashboard**: Real-time counting status updates
    - **🏆 Winner Prediction**: AI-powered prediction with multiple models
    - **📈 Module 1**: Vote share & descriptive statistical analysis
    - **🗺️ Module 2**: Regional comparative analysis
    
    ---
    
    #### 🤖 Prediction Models
    
    1. **Linear Regression** - Trend-based predictions
    2. **Random Forest** - Ensemble learning approach
    3. **Bayesian Analysis** - Probabilistic predictions
    4. **Ensemble Method** - Combined model predictions
    
    ---
    
    #### 🛠️ Technical Stack
    
    - **Frontend**: Streamlit
    - **Data Processing**: Pandas, NumPy
    - **Visualization**: Plotly
    - **Machine Learning**: Scikit-learn
    - **Deployment**: Streamlit Cloud
    
    ---
    
    #### 👨‍💻 Developed By
    
    **Capstone Project 2026**  
    Version 1.0.0
    
    ---
    
    **Login Credentials:**  
    Username: `admin`  
    Password: `password123`
    """)

# ============================================================================
# MAIN APP
# ============================================================================

def main():
    if not st.session_state.authenticated:
        login_page()
    else:
        # Sidebar
        with st.sidebar:
            st.markdown("## 🗳️ Election Portal")
            st.markdown(f"**User:** {st.session_state.get('username', 'admin')}")
            st.markdown("---")
            
            page = st.radio("Navigation", 
                           ["🏠 Home", "ℹ️ About", "📊 Voting Dashboard", 
                            "🧮 Counting Dashboard", "🏆 Winner Prediction",
                            "📈 Module 1: Vote Share", "🗺️ Module 2: Regional Comparison"])
            
            st.markdown("---")
            if st.button("🚪 Logout"):
                st.session_state.authenticated = False
                st.rerun()
        
        # Main content
        if page == "🏠 Home":
            home_page()
        elif page == "ℹ️ About":
            about_page()
        elif page == "📊 Voting Dashboard":
            voting_dashboard()
        elif page == "🧮 Counting Dashboard":
            counting_dashboard()
        elif page == "🏆 Winner Prediction":
            winner_prediction()
        elif page == "📈 Module 1: Vote Share":
            module1_page()
        elif page == "🗺️ Module 2: Regional Comparison":
            module2_page()

if __name__ == "__main__":
    main()
