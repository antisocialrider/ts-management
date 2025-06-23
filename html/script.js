let isUiVisible = false;
let currentTransactionHistory = [];
let currentEmployeeList = [];
let nearbyPlayers = [];
let jobRanks = [];
let selectedEmployeeForActions = null;

async function PostNuiCallback(eventName, data = {}) {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${eventName}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-m8',
            },
            body: JSON.stringify(data),
        });
        const result = await response.json();
        return result;
    } catch (error) {
        console.error(`Error in PostNuiCallback for ${eventName}:`, error);
        displayMessage(`NUI communication error: ${eventName}`, 'error');
        return { status: 'error', message: 'NUI communication failed' };
    }
}

function displayMessage(message, type = 'info') {
    const notificationContainer = document.getElementById('notificationContainer');

    const notification = document.createElement('div');
    notification.className = `toast-notification ${type}`;
    
    let iconClass = '';
    if (type === 'success') {
        iconClass = 'fas fa-check-circle';
    } else if (type === 'error') {
        iconClass = 'fas fa-times-circle';
    } else {
        iconClass = 'fas fa-info-circle';
    }

    notification.innerHTML = `<i class="${iconClass}"></i><span>${message}</span>`;
    
    notificationContainer.appendChild(notification);

    setTimeout(() => {
        notification.classList.add('show');
    }, 50);

    const displayDuration = 4000;
    const fadeDuration = 300;

    setTimeout(() => {
        notification.classList.remove('show');
        notification.classList.add('hide');
        setTimeout(() => {
            notification.remove();
        }, fadeDuration);
    }, displayDuration);
}

function updateSocietyBalance(balance) {
    document.getElementById('societyBalance').textContent = `$${balance.toFixed(2)}`;
}

function renderTransactionHistory(historyToRender) {
    console.log('Rendering history:', historyToRender);
    const listContainer = document.getElementById('transactionHistoryList');
    listContainer.innerHTML = '';

    if (historyToRender.length === 0) {
        listContainer.innerHTML = '<p class="text-center text-gray-500">No transactions recorded matching criteria.</p>';
        return;
    }

    historyToRender.forEach(transaction => {
        const transactionItem = document.createElement('div');
        const amountClass = (transaction.type === 'deposit') ? 'text-green-400' : 'text-red-400';
        
        const typeIcon = (transaction.type === 'deposit') ? 'fas fa-arrow-up' : 'fas fa-arrow-down';
        const typeLabel = transaction.type.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());

        transactionItem.innerHTML = `
            <div>
                <span class="main-info ${amountClass}"><i class="${typeIcon}"></i> ${typeLabel}: $${transaction.amount ? transaction.amount.toFixed(2) : 'N/A'}</span>
                <span class="sub-info">By: ${transaction.initiator || 'System'} | ${new Date(transaction.timestamp).toLocaleString()}</span>
                ${transaction.targetPlayerName ? `<span class="sub-info">To/From: ${transaction.targetPlayerName}</span>` : ''}
                ${transaction.reason ? `<span class="sub-info">Reason: ${transaction.reason}</span>` : ''}
            </div>
        `;
        listContainer.appendChild(transactionItem);
    });
}

function applyTransactionFiltersAndSort() {
    let filteredHistory = [...currentTransactionHistory];

    const searchTerm = document.getElementById('transactionSearch').value.toLowerCase();
    const sortBy = document.getElementById('transactionSort').value;

    if (searchTerm) {
        filteredHistory = filteredHistory.filter(transaction => {
            const typeMatch = transaction.type.toLowerCase().includes(searchTerm);
            const initiatorMatch = (transaction.initiator || '').toLowerCase().includes(searchTerm);
            const reasonMatch = (transaction.reason || '').toLowerCase().includes(searchTerm);
            const targetPlayerMatch = (transaction.targetPlayerName || '').toLowerCase().includes(searchTerm);
            return typeMatch || initiatorMatch || reasonMatch || targetPlayerMatch;
        });
    }

    filteredHistory.sort((a, b) => {
        if (sortBy === 'date_desc') {
            return b.timestamp - a.timestamp;
        } else if (sortBy === 'date_asc') {
            return a.timestamp - b.timestamp;
        } else if (sortBy === 'amount_desc') {
            return (b.amount || 0) - (a.amount || 0);
        } else if (sortBy === 'amount_asc') {
            return (a.amount || 0) - (b.amount || 0);
        }
        return 0;
    });

    renderTransactionHistory(filteredHistory);
}

function renderEmployeeList(employeesToRender) {
    console.log('Rendering employees:', employeesToRender);
    const employeeListContainer = document.getElementById('employeeList');
    employeeListContainer.innerHTML = '';

    if (employeesToRender.length === 0) {
        listContainer.innerHTML = '<p class="text-center text-gray-500">No employees loaded matching criteria.</p>';
        return;
    }

    employeesToRender.forEach(employee => {
        const employeeItem = document.createElement('div');
        employeeItem.className = 'data-list-item';
        employeeItem.innerHTML = `
            <span class="main-info">${employee.name} (${employee.id})</span>
            <span class="sub-info">Rank: ${employee.rank} <span class="status-indicator ${employee.isOnline ? 'online' : 'offline'}"></span> ${employee.isOnline ? 'Online' : 'Offline'}</span>
        `;
        employeeListContainer.appendChild(employeeItem);
    });
}

function applyEmployeeFiltersAndSort() {
    let filteredEmployees = [...currentEmployeeList];

    const searchTerm = document.getElementById('employeeSearch').value.toLowerCase();
    const sortBy = document.getElementById('employeeSort').value;

    if (searchTerm) {
        filteredEmployees = filteredEmployees.filter(employee => {
            const nameMatch = (employee.name || '').toLowerCase().includes(searchTerm);
            const idMatch = (employee.id || '').toLowerCase().includes(searchTerm);
            const rankMatch = (employee.rank || '').toLowerCase().includes(searchTerm);
            return nameMatch || idMatch || rankMatch;
        });
    }

    filteredEmployees.sort((a, b) => {
        if (sortBy === 'name_asc') {
            return (a.name || '').localeCompare(b.name || '');
        } else if (sortBy === 'name_desc') {
            return (b.name || '').localeCompare(a.name || '');
        } else if (sortBy === 'online_status') {
            if (a.isOnline && !b.isOnline) return -1;
            if (!a.isOnline && b.isOnline) return 1;
            return 0;
        }
        return 0;
    });

    renderEmployeeList(filteredEmployees);
}

function getFinanceFormData(type) {
    let amount;
    if (type === 'deposit') {
        amount = parseFloat(document.getElementById('amountDeposit').value);
    } else if (type === 'withdraw') {
        amount = parseFloat(document.getElementById('amountWithdraw').value);
    }

    if (isNaN(amount) || amount <= 0) {
        displayMessage('Please enter a valid positive amount.', 'error');
        return null;
    }
    return { amount: amount };
}

function populateNearbyPlayersDropdown(players) {
    const selectElement = document.getElementById('hirePlayerId');
    selectElement.innerHTML = '<option value="">Select a nearby player...</option>';

    if (players.length === 0) {
        const option = document.createElement('option');
        option.value = "";
        option.textContent = "No nearby players found.";
        option.disabled = true;
        selectElement.appendChild(option);
        return;
    }

    players.forEach(player => {
        const option = document.createElement('option');
        option.value = player.id;
        option.textContent = `${player.name} (Current Job: ${player.job})`;
        selectElement.appendChild(option);
    });
}

function populateJobRanksDropdown(ranks) {
    const selectElement = document.getElementById('hireRank');
    selectElement.innerHTML = '<option value="">Select a rank...</option>';

    if (ranks.length === 0) {
        const option = document.createElement('option');
        option.value = "";
        option.textContent = "No ranks available.";
        option.disabled = true;
        selectElement.appendChild(option);
        return;
    }

    ranks.forEach(rank => {
        const option = document.createElement('option');
        option.value = rank.name;
        option.textContent = rank.label;
        selectElement.appendChild(option);
    });
}

function renderSelectableEmployeeList(employees) {
    const employeeActionListContainer = document.getElementById('employeeActionList');
    employeeActionListContainer.innerHTML = '';

    if (employees.length === 0) {
        employeeActionListContainer.innerHTML = '<p class="text-center text-gray-500">No employees found in your job.</p>';
        return;
    }

    employees.sort((a, b) => {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return (a.name || '').localeCompare(b.name || '');
    });

    employees.forEach(employee => {
        const employeeItem = document.createElement('div');
        employeeItem.className = `data-list-item employee-action-item ${selectedEmployeeForActions && selectedEmployeeForActions.id === employee.id ? 'selected' : ''}`;
        employeeItem.dataset.employeeId = employee.id;

        employeeItem.innerHTML = `
            <span class="main-info">${employee.name} (${employee.id})</span>
            <span class="sub-info">Rank: ${employee.rank} <span class="status-indicator ${employee.isOnline ? 'online' : 'offline'}"></span> ${employee.isOnline ? 'Online' : 'Offline'}</span>
        `;
        
        employeeItem.addEventListener('click', () => {
            if (selectedEmployeeForActions && selectedEmployeeForActions.id === employee.id) {
                selectedEmployeeForActions = null;
                employeeItem.classList.remove('selected');
                displayMessage(`Deselected: ${employee.name} (${employee.id})`, 'info');
            } else {
                document.querySelectorAll('.employee-action-item').forEach(item => {
                    item.classList.remove('selected');
                });
                employeeItem.classList.add('selected');
                selectedEmployeeForActions = employee;
                displayMessage(`Selected: ${employee.name} (${employee.id})`, 'info');
            }
            toggleActionButtons();
        });
        employeeActionListContainer.appendChild(employeeItem);
    });
    toggleActionButtons();
}

function toggleActionButtons() {
    const employeeActionsContainer = document.getElementById('employeeActionsContainer');
    const promoteBtn = document.getElementById('promoteEmployeeBtn');
    const demoteBtn = document.getElementById('demoteEmployeeBtn');
    const fireBtn = document.getElementById('fireEmployeeBtn');

    const isEmployeeSelected = selectedEmployeeForActions !== null;

    console.log('toggleActionButtons called. isEmployeeSelected:', isEmployeeSelected);
    console.log('Before toggle, employeeActionsContainer classes:', employeeActionsContainer.classList.value);
    console.log('Before toggle, employeeActionsContainer display style:', window.getComputedStyle(employeeActionsContainer).display);


    if (isEmployeeSelected) {
        employeeActionsContainer.classList.remove('hidden-by-js');
        employeeActionsContainer.style.display = 'block';
    } else {
        employeeActionsContainer.classList.add('hidden-by-js');
        employeeActionsContainer.style.display = 'none';
    }
    console.log('After toggle, employeeActionsContainer classes:', employeeActionsContainer.classList.value);
    console.log('After toggle, employeeActionsContainer display style:', window.getComputedStyle(employeeActionsContainer).display);


    promoteBtn.disabled = !isEmployeeSelected;
    demoteBtn.disabled = !isEmployeeSelected;
    fireBtn.disabled = !isEmployeeSelected;
}


function showSection(sectionId) {
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
    });
    document.getElementById(sectionId).classList.add('active');

    document.querySelectorAll('.sidebar-nav button').forEach(button => {
        button.classList.remove('active');
    });
    if (sectionId === 'employeesSection') {
        document.getElementById('navEmployees').classList.add('active');
        PostNuiCallback('ts-management:requestEmployeeList');
        selectedEmployeeForActions = null;
        toggleActionButtons();
    } else if (sectionId === 'financesSection') {
        document.getElementById('navFinances').classList.add('active');
        PostNuiCallback('ts-management:requestSocietyFunds');
        PostNuiCallback('ts-management:requestTransactionHistory');
        selectedEmployeeForActions = null;
        toggleActionButtons();
    } else if (sectionId === 'announcementsSection') {
        document.getElementById('navAnnouncements').classList.add('active');
        selectedEmployeeForActions = null;
        toggleActionButtons();
    } else if (sectionId === 'employeeManagementSection') {
        document.getElementById('navEmployeeManagement').classList.add('active');
        PostNuiCallback('ts-management:requestNearbyPlayers');
        PostNuiCallback('ts-management:requestJobRanks');
        PostNuiCallback('ts-management:requestEmployeeList');
        selectedEmployeeForActions = null;
        toggleActionButtons();
    }
}


document.addEventListener('DOMContentLoaded', () => {
    document.querySelector('.main-wrapper').style.display = 'none';
    window.addEventListener('message', (event) => {
        const eventData = event.data;

        if (eventData.type === 'uiState') {
            isUiVisible = eventData.state;
            const mainWrapper = document.querySelector('.main-wrapper');
            if (isUiVisible) {
                mainWrapper.style.display = 'flex';
                showSection('employeesSection');
            } else {
                mainWrapper.style.display = 'none';
            }
        } else if (eventData.type === 'updateSocietyFunds') {
            updateSocietyBalance(eventData.balance);
        } else if (eventData.type === 'updateTransactionHistory') {
            currentTransactionHistory = eventData.history || []; 
            applyTransactionFiltersAndSort();
        } else if (eventData.type === 'updateEmployeeList') {
            currentEmployeeList = eventData.employees || [];
            applyEmployeeFiltersAndSort();
            renderSelectableEmployeeList(currentEmployeeList);
        } else if (eventData.type === 'updateNearbyPlayers') {
            nearbyPlayers = eventData.players || [];
            populateNearbyPlayersDropdown(nearbyPlayers);
        } else if (eventData.type === 'updateJobRanks') {
            jobRanks = eventData.ranks || [];
            populateJobRanksDropdown(jobRanks);
        } else if (eventData.type === 'serverNotification') {
            displayMessage(eventData.message, eventData.status);
        }
    });

    document.getElementById('navEmployees').addEventListener('click', () => {
        console.log('Employees button clicked');
        showSection('employeesSection');
    });
    document.getElementById('navFinances').addEventListener('click', () => {
        console.log('Finances button clicked');
        showSection('financesSection');
    });
    document.getElementById('navAnnouncements').addEventListener('click', () => {
        console.log('Announcements button clicked');
        showSection('announcementsSection');
    });
    document.getElementById('navEmployeeManagement').addEventListener('click', () => {
        console.log('Employee Management button clicked');
        showSection('employeeManagementSection');
    });

    document.getElementById('depositBtn').addEventListener('click', () => {
        const data = getFinanceFormData('deposit');
        if (data) {
            PostNuiCallback('ts-management:depositFunds', { amount: data.amount });
            document.getElementById('amountDeposit').value = '';
        }
    });

    document.getElementById('withdrawBtn').addEventListener('click', () => {
        const data = getFinanceFormData('withdraw');
        if (data) {
            PostNuiCallback('ts-management:withdrawFunds', { amount: data.amount });
            document.getElementById('amountWithdraw').value = '';
        }
    });

    document.getElementById('promoteEmployeeBtn').addEventListener('click', () => {
        if (selectedEmployeeForActions) {
            PostNuiCallback('ts-management:promoteEmployee', selectedEmployeeForActions.id);
            selectedEmployeeForActions = null;
            renderSelectableEmployeeList(currentEmployeeList); 
        } else {
            displayMessage('Please select an employee to promote.', 'error');
        }
    });

    document.getElementById('demoteEmployeeBtn').addEventListener('click', () => {
        if (selectedEmployeeForActions) {
            PostNuiCallback('ts-management:demoteEmployee', selectedEmployeeForActions.id);
            selectedEmployeeForActions = null;
            renderSelectableEmployeeList(currentEmployeeList);
        } else {
            displayMessage('Please select an employee to demote.', 'error');
        }
    });

    document.getElementById('fireEmployeeBtn').addEventListener('click', () => {
        if (selectedEmployeeForActions) {
            PostNuiCallback('ts-management:fireEmployee', selectedEmployeeForActions.id);
            selectedEmployeeForActions = null;
            renderSelectableEmployeeList(currentEmployeeList);
        } else {
            displayMessage('Please select an employee to fire.', 'error');
        }
    });

    document.getElementById('transactionSearch').addEventListener('input', applyTransactionFiltersAndSort);
    document.getElementById('transactionSort').addEventListener('change', applyTransactionFiltersAndSort);
    document.getElementById('employeeSearch').addEventListener('input', applyEmployeeFiltersAndSort);
    document.getElementById('employeeSort').addEventListener('change', applyEmployeeFiltersAndSort);

    document.getElementById('sendAnnouncementBtn').addEventListener('click', () => {
        const message = document.getElementById('announcementMessage').value.trim();
        if (message) {
            PostNuiCallback('ts-management:sendAnnouncement', { message: message });
            document.getElementById('announcementMessage').value = '';
        } else {
            displayMessage('Announcement message cannot be empty.', 'error');
        }
    });

    document.getElementById('hireEmployeeBtn').addEventListener('click', () => {
        const targetPlayerId = document.getElementById('hirePlayerId').value;
        const initialRank = document.getElementById('hireRank').value;

        if (!targetPlayerId) {
            displayMessage('Please select a player to hire.', 'error');
            return;
        }
        if (!initialRank) {
            displayMessage('Please select a rank for the new employee.', 'error');
            return;
        }

        PostNuiCallback('ts-management:hireEmployee', { targetPlayerId: targetPlayerId, initialRank: initialRank });
        document.getElementById('hirePlayerId').value = '';
        document.getElementById('hireRank').value = '';
    });


    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            if (isUiVisible) {
                PostNuiCallback('ts-management:closeUI');
            }
        }
    });

    setTimeout(toggleActionButtons, 100);
});
