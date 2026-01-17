# Election Result Statistical Analysis Portal
# Main Application File: app.R

library(shiny)
library(shinydashboard)
library(shinyjs)
library(shinyWidgets)
library(tidyverse)
library(plotly)
library(DT)
library(leaflet)
library(sf)
library(viridis)
library(scales)
library(bslib)
library(thematic)

# Source modules
source("modules/auth_module.R")
source("modules/data_processing.R")
source("modules/voting_analysis.R")
source("modules/counting_analysis.R")
source("modules/prediction_model.R")
source("utils/theme_config.R")

# Sample Data Generation (Replace with real data)
generate_sample_data <- function() {
  set.seed(42)
  
  regions <- c("North", "South", "East", "West", "Central")
  parties <- c("Party A", "Party B", "Party C", "Party D", "Independent")
  
  # Generate constituency-level data
  constituencies <- expand.grid(
    region = regions,
    constituency_id = 1:20,
    stringsAsFactors = FALSE
  ) %>%
    mutate(
      constituency_name = paste0(region, " Constituency ", constituency_id),
      total_voters = sample(50000:200000, n(), replace = TRUE)
    )
  
  # Generate voting data
  voting_data <- constituencies %>%
    crossing(party = parties) %>%
    mutate(
      votes = map2_dbl(total_voters, party, ~{
        base_turnout <- runif(1, 0.6, 0.85)
        party_strength <- case_when(
          party == "Party A" ~ runif(1, 0.25, 0.35),
          party == "Party B" ~ runif(1, 0.20, 0.30),
          party == "Party C" ~ runif(1, 0.15, 0.25),
          party == "Party D" ~ runif(1, 0.10, 0.20),
          TRUE ~ runif(1, 0.05, 0.15)
        )
        round(.x * base_turnout * party_strength)
      }),
      vote_share = votes / sum(votes),
      .by = c(region, constituency_name)
    )
  
  # Generate real-time counting data
  counting_data <- voting_data %>%
    mutate(
      counted_votes = round(votes * runif(n(), 0.75, 0.95)),
      counting_status = sample(c("Complete", "In Progress", "Pending"), n(), 
                               replace = TRUE, prob = c(0.7, 0.25, 0.05))
    )
  
  list(
    constituencies = constituencies,
    voting_data = voting_data,
    counting_data = counting_data
  )
}

# Initialize data
election_data <- generate_sample_data()

# UI Definition
ui <- dashboardPage(
  skin = "blue",
  
  # Header
  dashboardHeader(
    title = tags$div(
      tags$i(class = "fa fa-poll-h"),
      " Election Analytics Portal"
    ),
    titleWidth = 300
  ),
  
  # Sidebar
  dashboardSidebar(
    width = 300,
    useShinyjs(),
    
    div(id = "sidebar_content",
        sidebarMenu(
          id = "sidebar_menu",
          
          menuItem("Home", tabName = "home", icon = icon("home")),
          menuItem("About", tabName = "about", icon = icon("info-circle")),
          
          hr(),
          tags$h5("Analysis Modules", style = "padding-left: 15px; color: #ecf0f5;"),
          
          menuItem("Voting Dashboard", tabName = "voting", icon = icon("vote-yea"),
                   badgeLabel = "Live", badgeColor = "green"),
          
          menuItem("Counting Dashboard", tabName = "counting", icon = icon("calculator"),
                   badgeLabel = "Real-time", badgeColor = "orange"),
          
          menuItem("Winner Prediction", tabName = "prediction", icon = icon("trophy"),
                   badgeLabel = "AI", badgeColor = "purple"),
          
          menuItem("Module 1: Vote Share Analysis", tabName = "module1", 
                   icon = icon("chart-pie")),
          
          menuItem("Module 2: Regional Comparison", tabName = "module2", 
                   icon = icon("map-marked-alt")),
          
          hr(),
          
          menuItem("Logout", tabName = "logout", icon = icon("sign-out-alt"))
        )
    ),
    
    div(id = "login_sidebar",
        style = "display: none;",
        tags$div(
          style = "padding: 20px;",
          tags$img(src = "logo.png", width = "100%", 
                   onerror = "this.style.display='none'"),
          tags$h4("Please Login", style = "color: white; text-align: center;")
        )
    )
  ),
  
  # Body
  dashboardBody(
    useShinyjs(),
    
    # Custom CSS
    tags$head(
      tags$style(HTML("
        @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap');
        
        body, .content-wrapper, .main-sidebar {
          font-family: 'Roboto', sans-serif;
        }
        
        .info-box {
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
          transition: transform 0.3s ease;
        }
        
        .info-box:hover {
          transform: translateY(-5px);
          box-shadow: 0 6px 12px rgba(0,0,0,0.15);
        }
        
        .box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .login-box {
          max-width: 400px;
          margin: 100px auto;
          background: white;
          padding: 30px;
          border-radius: 10px;
          box-shadow: 0 8px 16px rgba(0,0,0,0.2);
        }
        
        .stat-card {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 20px;
          border-radius: 10px;
          margin: 10px 0;
        }
        
        .winner-card {
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
          color: white;
          padding: 25px;
          border-radius: 10px;
          text-align: center;
          font-size: 24px;
          font-weight: bold;
        }
      "))
    ),
    
    tabItems(
      # Login Page
      tabItem(
        tabName = "login",
        div(id = "login_page",
            div(class = "login-box",
                tags$h2("Election Portal Login", 
                        style = "text-align: center; color: #3c8dbc;"),
                tags$hr(),
                textInput("username", "Username", 
                          placeholder = "Enter username"),
                passwordInput("password", "Password", 
                              placeholder = "Enter password"),
                tags$br(),
                actionButton("login_btn", "Login", 
                            class = "btn-primary btn-block btn-lg",
                            icon = icon("sign-in-alt")),
                tags$br(),
                tags$div(
                  style = "text-align: center; margin-top: 20px; color: #666;",
                  tags$small("Demo credentials: admin / password123")
                )
            )
        )
      ),
      
      # Home Page
      tabItem(
        tabName = "home",
        div(id = "home_content", style = "display: none;",
            fluidRow(
              column(12,
                     tags$div(
                       style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                                color: white; padding: 40px; border-radius: 10px; 
                                text-align: center; margin-bottom: 30px;",
                       tags$h1(icon("poll-h"), " Election Result Analysis Portal"),
                       tags$h3("Real-time Statistical Analysis & Prediction System"),
                       tags$p("Comprehensive election data visualization, analysis, and AI-powered predictions")
                     )
              )
            ),
            
            fluidRow(
              infoBoxOutput("total_votes_box", width = 3),
              infoBoxOutput("total_constituencies_box", width = 3),
              infoBoxOutput("turnout_box", width = 3),
              infoBoxOutput("leading_party_box", width = 3)
            ),
            
            fluidRow(
              box(
                title = "Quick Navigation",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                fluidRow(
                  column(4,
                         actionButton("nav_voting", "Voting Dashboard",
                                    class = "btn-success btn-block btn-lg",
                                    icon = icon("vote-yea"),
                                    style = "height: 100px; font-size: 18px;")
                  ),
                  column(4,
                         actionButton("nav_counting", "Counting Dashboard",
                                    class = "btn-warning btn-block btn-lg",
                                    icon = icon("calculator"),
                                    style = "height: 100px; font-size: 18px;")
                  ),
                  column(4,
                         actionButton("nav_prediction", "Winner Prediction",
                                    class = "btn-danger btn-block btn-lg",
                                    icon = icon("trophy"),
                                    style = "height: 100px; font-size: 18px;")
                  )
                )
              )
            ),
            
            fluidRow(
              box(
                title = "Overall Party Performance",
                status = "info",
                solidHeader = TRUE,
                width = 8,
                plotlyOutput("home_party_chart", height = "400px")
              ),
              
              box(
                title = "Regional Distribution",
                status = "warning",
                solidHeader = TRUE,
                width = 4,
                plotlyOutput("home_region_chart", height = "400px")
              )
            )
        )
      ),
      
      # About Page
      tabItem(
        tabName = "about",
        div(id = "about_content", style = "display: none;",
            fluidRow(
              box(
                title = "About This Portal",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                tags$h3("Election Result Statistical Analysis Portal"),
                tags$hr(),
                
                tags$h4(icon("bullseye"), " Objective"),
                tags$p("This comprehensive election analysis portal provides real-time statistical 
                       analysis, visualization, and AI-powered predictions for election results. 
                       Built with advanced R analytics and interactive visualizations."),
                
                tags$h4(icon("cogs"), " Key Features"),
                tags$ul(
                  tags$li(tags$b("Real-time Voting Dashboard:"), " Live vote tracking and analysis"),
                  tags$li(tags$b("Counting Dashboard:"), " Real-time counting status and updates"),
                  tags$li(tags$b("Winner Prediction:"), " AI-powered prediction models using statistical algorithms"),
                  tags$li(tags$b("Vote Share Analysis:"), " Comprehensive descriptive statistics and visualizations"),
                  tags$li(tags$b("Regional Comparison:"), " Interactive regional analysis and comparisons")
                ),
                
                tags$h4(icon("chart-line"), " Analytical Modules"),
                
                fluidRow(
                  column(6,
                         tags$div(
                           class = "stat-card",
                           tags$h5(icon("chart-pie"), " Module 1: Vote Share & Descriptive Analysis"),
                           tags$p("Detailed statistical analysis including vote distribution, 
                                  party performance metrics, and descriptive statistics across 
                                  all constituencies.")
                         )
                  ),
                  column(6,
                         tags$div(
                           class = "stat-card",
                           tags$h5(icon("map-marked-alt"), " Module 2: Comparative Dashboard by Region"),
                           tags$p("Regional comparative analysis with interactive maps, 
                                  cross-regional performance metrics, and geographic voting patterns.")
                         )
                  )
                ),
                
                tags$br(),
                
                tags$h4(icon("database"), " Technical Stack"),
                tags$ul(
                  tags$li("R Programming Language"),
                  tags$li("Shiny Framework for Interactive Web Applications"),
                  tags$li("Plotly for Advanced Visualizations"),
                  tags$li("Statistical Modeling with tidyverse"),
                  tags$li("Real-time Data Processing")
                ),
                
                tags$hr(),
                
                tags$div(
                  style = "text-align: center; padding: 20px;",
                  tags$h5("Developed for Advanced Statistical Analysis"),
                  tags$p("Version 1.0 | © 2026 Election Analytics Portal")
                )
              )
            )
        )
      ),
      
      # Voting Dashboard
      tabItem(
        tabName = "voting",
        div(id = "voting_content", style = "display: none;",
            h2(icon("vote-yea"), " Voting Dashboard - Live Analysis"),
            
            fluidRow(
              box(
                title = "Filters",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                fluidRow(
                  column(3,
                         selectInput("voting_region", "Select Region",
                                   choices = c("All", unique(election_data$voting_data$region)),
                                   selected = "All")
                  ),
                  column(3,
                         selectInput("voting_party", "Select Party",
                                   choices = c("All", unique(election_data$voting_data$party)),
                                   selected = "All")
                  ),
                  column(3,
                         sliderInput("voting_votes_range", "Vote Range",
                                   min = 0, max = 100000, value = c(0, 100000))
                  ),
                  column(3,
                         actionButton("refresh_voting", "Refresh Data",
                                    class = "btn-success",
                                    icon = icon("sync"),
                                    style = "margin-top: 25px;")
                  )
                )
              )
            ),
            
            fluidRow(
              box(
                title = "Vote Distribution by Party",
                status = "info",
                solidHeader = TRUE,
                width = 8,
                plotlyOutput("voting_distribution_chart", height = "400px")
              ),
              
              box(
                title = "Top Constituencies",
                status = "success",
                solidHeader = TRUE,
                width = 4,
                plotlyOutput("voting_top_constituencies", height = "400px")
              )
            ),
            
            fluidRow(
              box(
                title = "Detailed Voting Data",
                status = "warning",
                solidHeader = TRUE,
                width = 12,
                DTOutput("voting_data_table")
              )
            )
        )
      ),
      
      # Counting Dashboard
      tabItem(
        tabName = "counting",
        div(id = "counting_content", style = "display: none;",
            h2(icon("calculator"), " Counting Dashboard - Real-time Updates"),
            
            fluidRow(
              valueBoxOutput("counting_complete_box", width = 4),
              valueBoxOutput("counting_progress_box", width = 4),
              valueBoxOutput("counting_pending_box", width = 4)
            ),
            
            fluidRow(
              box(
                title = "Counting Progress by Region",
                status = "primary",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("counting_progress_chart", height = "400px")
              ),
              
              box(
                title = "Current Leading Party",
                status = "success",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("counting_leading_chart", height = "400px")
              )
            ),
            
            fluidRow(
              box(
                title = "Real-time Counting Status",
                status = "info",
                solidHeader = TRUE,
                width = 12,
                DTOutput("counting_status_table")
              )
            )
        )
      ),
      
      # Winner Prediction
      tabItem(
        tabName = "prediction",
        div(id = "prediction_content", style = "display: none;",
            h2(icon("trophy"), " Winner Prediction - AI-Powered Analysis"),
            
            fluidRow(
              box(
                title = "Prediction Model Configuration",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                fluidRow(
                  column(4,
                         selectInput("pred_model", "Prediction Model",
                                   choices = c("Linear Regression", "Random Forest", 
                                             "Bayesian Analysis", "Ensemble"),
                                   selected = "Ensemble")
                  ),
                  column(4,
                         sliderInput("pred_confidence", "Confidence Level",
                                   min = 0.80, max = 0.99, value = 0.95, step = 0.01)
                  ),
                  column(4,
                         actionButton("run_prediction", "Run Prediction",
                                    class = "btn-danger btn-lg",
                                    icon = icon("play"),
                                    style = "margin-top: 25px;")
                  )
                )
              )
            ),
            
            fluidRow(
              box(
                title = "Predicted Winner",
                status = "danger",
                solidHeader = TRUE,
                width = 12,
                uiOutput("prediction_winner_ui")
              )
            ),
            
            fluidRow(
              box(
                title = "Win Probability by Party",
                status = "warning",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("prediction_probability_chart", height = "400px")
              ),
              
              box(
                title = "Prediction Confidence Intervals",
                status = "info",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("prediction_confidence_chart", height = "400px")
              )
            )
        )
      ),
      
      # Module 1: Vote Share Analysis
      tabItem(
        tabName = "module1",
        div(id = "module1_content", style = "display: none;",
            h2(icon("chart-pie"), " Module 1: Vote Share & Descriptive Analysis"),
            
            fluidRow(
              box(
                title = "Statistical Summary",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                verbatimTextOutput("module1_summary")
              )
            ),
            
            fluidRow(
              box(
                title = "Vote Share Distribution",
                status = "info",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("module1_vote_share_chart", height = "400px")
              ),
              
              box(
                title = "Party Performance Metrics",
                status = "success",
                solidHeader = TRUE,
                width = 6,
                plotlyOutput("module1_performance_chart", height = "400px")
              )
            ),
            
            fluidRow(
              box(
                title = "Descriptive Statistics Table",
                status = "warning",
                solidHeader = TRUE,
                width = 12,
                DTOutput("module1_stats_table")
              )
            )
        )
      ),
      
      # Module 2: Regional Comparison
      tabItem(
        tabName = "module2",
        div(id = "module2_content", style = "display: none;",
            h2(icon("map-marked-alt"), " Module 2: Comparative Dashboard by Region"),
            
            fluidRow(
              box(
                title = "Regional Selection",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                checkboxGroupInput("module2_regions", "Compare Regions",
                                 choices = unique(election_data$voting_data$region),
                                 selected = unique(election_data$voting_data$region)[1:3],
                                 inline = TRUE)
              )
            ),
            
            fluidRow(
              box(
                title = "Regional Vote Comparison",
                status = "info",
                solidHeader = TRUE,
                width = 8,
                plotlyOutput("module2_regional_comparison", height = "500px")
              ),
              
              box(
                title = "Regional Metrics",
                status = "success",
                solidHeader = TRUE,
                width = 4,
                plotlyOutput("module2_regional_metrics", height = "500px")
              )
            ),
            
            fluidRow(
              box(
                title = "Cross-Regional Analysis",
                status = "warning",
                solidHeader = TRUE,
                width = 12,
                DTOutput("module2_comparison_table")
              )
            )
        )
      )
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  
  # Authentication state
  authenticated <- reactiveVal(FALSE)
  
  # Show login page initially
  observe({
    if (!authenticated()) {
      updateTabItems(session, "sidebar_menu", "login")
      shinyjs::hide("sidebar_content")
      shinyjs::show("login_sidebar")
      shinyjs::hide("home_content")
      shinyjs::hide("about_content")
      shinyjs::hide("voting_content")
      shinyjs::hide("counting_content")
      shinyjs::hide("prediction_content")
      shinyjs::hide("module1_content")
      shinyjs::hide("module2_content")
    } else {
      shinyjs::show("sidebar_content")
      shinyjs::hide("login_sidebar")
    }
  })
  
  # Login logic
  observeEvent(input$login_btn, {
    if (input$username == "admin" && input$password == "password123") {
      authenticated(TRUE)
      updateTabItems(session, "sidebar_menu", "home")
      shinyjs::show("home_content")
      showNotification("Login successful!", type = "message", duration = 3)
    } else {
      showNotification("Invalid credentials!", type = "error", duration = 3)
    }
  })
  
  # Logout logic
  observeEvent(input$sidebar_menu, {
    if (input$sidebar_menu == "logout") {
      authenticated(FALSE)
      updateTabItems(session, "sidebar_menu", "login")
      showNotification("Logged out successfully!", type = "message", duration = 3)
    }
  })
  
  # Show/hide content based on tab selection
  observe({
    req(authenticated())
    
    shinyjs::hide("home_content")
    shinyjs::hide("about_content")
    shinyjs::hide("voting_content")
    shinyjs::hide("counting_content")
    shinyjs::hide("prediction_content")
    shinyjs::hide("module1_content")
    shinyjs::hide("module2_content")
    
    if (input$sidebar_menu == "home") shinyjs::show("home_content")
    if (input$sidebar_menu == "about") shinyjs::show("about_content")
    if (input$sidebar_menu == "voting") shinyjs::show("voting_content")
    if (input$sidebar_menu == "counting") shinyjs::show("counting_content")
    if (input$sidebar_menu == "prediction") shinyjs::show("prediction_content")
    if (input$sidebar_menu == "module1") shinyjs::show("module1_content")
    if (input$sidebar_menu == "module2") shinyjs::show("module2_content")
  })
  
  # Navigation buttons
  observeEvent(input$nav_voting, {
    updateTabItems(session, "sidebar_menu", "voting")
  })
  
  observeEvent(input$nav_counting, {
    updateTabItems(session, "sidebar_menu", "counting")
  })
  
  observeEvent(input$nav_prediction, {
    updateTabItems(session, "sidebar_menu", "prediction")
  })
  
  # HOME PAGE OUTPUTS
  output$total_votes_box <- renderInfoBox({
    total_votes <- sum(election_data$voting_data$votes)
    infoBox(
      "Total Votes Cast",
      format(total_votes, big.mark = ","),
      icon = icon("vote-yea"),
      color = "blue"
    )
  })
  
  output$total_constituencies_box <- renderInfoBox({
    total_const <- nrow(election_data$constituencies)
    infoBox(
      "Total Constituencies",
      total_const,
      icon = icon("map-marker-alt"),
      color = "green"
    )
  })
  
  output$turnout_box <- renderInfoBox({
    turnout <- sum(election_data$voting_data$votes) / 
               sum(election_data$constituencies$total_voters) * 100
    infoBox(
      "Voter Turnout",
      paste0(round(turnout, 1), "%"),
      icon = icon("users"),
      color = "yellow"
    )
  })
  
  output$leading_party_box <- renderInfoBox({
    leading <- election_data$voting_data %>%
      group_by(party) %>%
      summarise(total = sum(votes)) %>%
      arrange(desc(total)) %>%
      slice(1)
    
    infoBox(
      "Leading Party",
      leading$party,
      icon = icon("trophy"),
      color = "red"
    )
  })
  
  output$home_party_chart <- renderPlotly({
    data <- election_data$voting_data %>%
      group_by(party) %>%
      summarise(total_votes = sum(votes)) %>%
      arrange(desc(total_votes))
    
    plot_ly(data, x = ~party, y = ~total_votes, type = "bar",
            marker = list(color = viridis(nrow(data)))) %>%
      layout(title = "Total Votes by Party",
             xaxis = list(title = "Party"),
             yaxis = list(title = "Total Votes"))
  })
  
  output$home_region_chart <- renderPlotly({
    data <- election_data$voting_data %>%
      group_by(region) %>%
      summarise(total_votes = sum(votes))
    
    plot_ly(data, labels = ~region, values = ~total_votes, type = "pie") %>%
      layout(title = "Regional Distribution")
  })
  
  # VOTING DASHBOARD OUTPUTS
  output$voting_distribution_chart <- renderPlotly({
    data <- election_data$voting_data %>%
      group_by(party) %>%
      summarise(total_votes = sum(votes))
    
    plot_ly(data, x = ~party, y = ~total_votes, type = "bar",
            marker = list(color = viridis(nrow(data)))) %>%
      layout(xaxis = list(title = "Party"),
             yaxis = list(title = "Votes"))
  })
  
  output$voting_top_constituencies <- renderPlotly({
    data <- election_data$voting_data %>%
      group_by(constituency_name) %>%
      summarise(total_votes = sum(votes)) %>%
      arrange(desc(total_votes)) %>%
      slice(1:10)
    
    plot_ly(data, y = ~constituency_name, x = ~total_votes, 
            type = "bar", orientation = "h") %>%
      layout(yaxis = list(title = ""), xaxis = list(title = "Votes"))
  })
  
  output$voting_data_table <- renderDT({
    datatable(election_data$voting_data, 
              options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # COUNTING DASHBOARD OUTPUTS
  output$counting_complete_box <- renderValueBox({
    complete <- sum(election_data$counting_data$counting_status == "Complete")
    valueBox(
      complete,
      "Constituencies Counted",
      icon = icon("check-circle"),
      color = "green"
    )
  })
  
  output$counting_progress_box <- renderValueBox({
    progress <- sum(election_data$counting_data$counting_status == "In Progress")
    valueBox(
      progress,
      "Counting in Progress",
      icon = icon("spinner"),
      color = "yellow"
    )
  })
  
  output$counting_pending_box <- renderValueBox({
    pending <- sum(election_data$counting_data$counting_status == "Pending")
    valueBox(
      pending,
      "Pending Count",
      icon = icon("clock"),
      color = "red"
    )
  })
  
  output$counting_progress_chart <- renderPlotly({
    data <- election_data$counting_data %>%
      group_by(region, counting_status) %>%
      summarise(count = n(), .groups = "drop")
    
    plot_ly(data, x = ~region, y = ~count, color = ~counting_status,
            type = "bar") %>%
      layout(barmode = "stack", xaxis = list(title = "Region"),
             yaxis = list(title = "Count"))
  })
  
  output$counting_leading_chart <- renderPlotly({
    data <- election_data$counting_data %>%
      group_by(party) %>%
      summarise(counted = sum(counted_votes))
    
    plot_ly(data, labels = ~party, values = ~counted, type = "pie")
  })
  
  output$counting_status_table <- renderDT({
    datatable(election_data$counting_data,
              options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # PREDICTION OUTPUTS
  output$prediction_winner_ui <- renderUI({
    winner <- election_data$voting_data %>%
      group_by(party) %>%
      summarise(total = sum(votes)) %>%
      arrange(desc(total)) %>%
      slice(1)
    
    tags$div(
      class = "winner-card",
      tags$h2(icon("trophy"), " Predicted Winner"),
      tags$h1(winner$party),
      tags$p(paste("Projected Votes:", format(winner$total, big.mark = ",")))
    )
  })
  
  output$prediction_probability_chart <- renderPlotly({
    set.seed(42)
    data <- election_data$voting_data %>%
      group_by(party) %>%
      summar
